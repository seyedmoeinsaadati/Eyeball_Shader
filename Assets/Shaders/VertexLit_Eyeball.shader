Shader "Moein/VertexLit/Eyeball"
{
    Properties
    {
        [Header(Section A)]
        [Space(5)]
        _AColor("Color", Color) = (1,1,1)
        _ATexture("Texture", 2D) = "white"{}
        [KeywordEnum(Polar, Cartesian)] _ATextureMode("Texture Mode", Float) = 0
        _ATextureTiling("Polar: Scale(xy), Zoom (z)", Vector) = (2,1,1,0)


        [Space(5)]
        [Header(B)]
        [Space(5)]
        _BInColor("Tint Color", Color) = (1,1,1)
        _BTintColor("Shadow Color In", Color) = (1,1,1)
        _BOutColor("Shadow Color Out", Color) = (1,1,1)
        _BInSmooth("Smoothness In", Range(0, 0.5))= 0
        _BOutSmooth("Smoothness Out", Range(0, 0.5))= 0
        _BRadius("Radius", Range(0,.2))= 0
        _BScale("Scale", Range(0, 10))= 2
        
        _BTexture("Texture", 2D) = "white"{}
        [KeywordEnum(Polar, Cartesian)] _BTextureMode("Texture Mode", Float) = 0        
        _BTextureTiling("Polar: Scale(xy), Zoom (z)", Vector) = (2,1,1,0)

        [Space(5)]
        [Header(C)]
        [Space(5)]
        _CColor("Color", Color) = (0,0,0)
        _CRadius("Radius", Range(0, .2))= .5
        _CSmooth("Smoothness", Range(0, .2))= .05
        _CScale("Scale", Range(0, 10))= 1

        [Space(5)]
        [Toggle] _RimToggle("Rim", Float) = 0
        [HDR] _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimPower("Rim Power", Range(0,20)) = 1

        [Space(5)]
        [Header(_Lighting)]
        [Space(5)]
        _Ambient("Ambient Intensity", Range(0, 1)) = 1
        _LightInt ("Light Intensity", Range(0, 1)) = 1
        [HDR]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        [PowerSlider(2.0)]_SpecularPow("Specular Power", Range(0.0, 1024.0)) = 64

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode"="ForwardBase"}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile __ _RIMTOGGLE_ON
            #pragma multi_compile __ _NOISETOGGLE_ON
            #pragma multi_compile _BTEXTUREMODE_POLAR _BTEXTUREMODE_CARTESIAN
            #pragma multi_compile _ATEXTUREMODE_POLAR _ATEXTUREMODE_CARTESIAN
            
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

             float circle(float2 p, float center, float radius, float smooth)
            {
                float c = length(p - center) - radius;
                return smoothstep(c - smooth, c + smooth, radius);
            }

            float inCircle(float2 p, float center, float radius, float smooth)
            {
                float c = length(p - center) - radius;
                return smoothstep(c, c + smooth, radius);
            }

            float outCircle(float2 p, float center, float radius, float smooth)
            {
                float c = length(p - center) - radius;
                return smoothstep(c - smooth, c, radius);
            }

            float3 lambert_shading(float3 colorRefl, float lightInt, float3 normal, float3 lightDir)
            {
                return colorRefl * lightInt * max(0, dot(normal, lightDir));
            }

            float3 specular_shading(float3 colorRefl, float specularInt, float3 normal, float3 lightDir, float3 viewDir, float specularPow)
            {
                float3 h = normalize(lightDir + viewDir);
                return colorRefl * specularInt * pow(max (0 , dot(normal, h)), specularPow);
            }

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
            };

            struct v2f
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 lightColor : COLOR0;
                float3 specularColor : COLOR1;

#if _RIMTOGGLE_ON
                float4 rimColor : COLOR2;
#endif

            };

            // A Section
            sampler2D _ATexture;
            float4 _AColor, _ATextureTiling, _ATexture_ST;

            // B Section
            sampler2D _BTexture;
            float4 _BTintColor ,_BInColor, _BOutColor, _BTextureTiling, _BTexture_ST;
            float _BRadius, _BScale, _BInSmooth, _BOutSmooth;

            // C Section
            float _CRadius, _CSmooth, _CScale;
            float4 _CColor;

            float _Ambient;
            float _LightInt;
            float4 _SpecularColor;
            float _SpecularPow;

#if _RIMTOGGLE_ON
            float _RimPower;
            float4 _RimColor;
#endif
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
            
                o.lightColor = UNITY_LIGHTMODEL_AMBIENT * _Ambient;

                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                half3 diffuse = lambert_shading(_LightColor0.rgb, _LightInt, worldNormal, lightDir);
                o.lightColor += diffuse;
                
                float3 viewDir = normalize(WorldSpaceViewDir(v.vertex)).xyz;
                fixed3 specCol = _SpecularColor * _LightColor0.rgb;
                half3 specular = specular_shading(specCol, _SpecularColor.a, worldNormal, lightDir, viewDir, _SpecularPow);
                o.specularColor = specular;

#if _RIMTOGGLE_ON
                o.rimColor = pow(1- dot(viewDir, worldNormal), _RimPower);
#endif

                return o;
            }
            
            fixed4 frag (v2f i) : SV_TARGET
            {
                float r, a;
                float2 uv = i.uv;
#if _ATEXTUREMODE_POLAR
                uv *= _ATextureTiling.xy;
                uv.x += _ATextureTiling.x * -.25;
                uv.y += _ATextureTiling.y * -.5;
                r = length(uv) * 2;
                a = atan(uv.y / uv.x);
                uv = float2(r, a) * _ATextureTiling.z;
#elif _ATEXTUREMODE_CARTESIAN
                uv *= _ATexture_ST.xy;
                uv += _ATexture_ST.zw;
#endif
                fixed4 col = _AColor * tex2D(_ATexture, uv);
                
                uv = i.uv;
                uv.x *= _BScale;
                uv.x += _BScale * -.75 + .5;

                float bCircle = outCircle(uv, .5, _BRadius, _BOutSmooth);
                col = lerp(col, _BOutColor, bCircle);
                bCircle = circle(uv, .5, _BRadius, 0);
                col = lerp(col, _BTintColor, bCircle);
                bCircle = inCircle(uv, .5, _BRadius, _BInSmooth);
                
                // mapping texture on sphere (polar system / cartesian)
                uv = i.uv;
#if _BTEXTUREMODE_POLAR
                uv *= _BTextureTiling.xy;
                uv.x += _BTextureTiling.x * -.75;
                uv.y += _BTextureTiling.y * -.5;
                r = length(uv) * 2;
                a = atan(uv.y / uv.x);
                uv = float2(r, a) * _BTextureTiling.z;
#elif _BTEXTUREMODE_CARTESIAN
                uv *= _BTexture_ST.xy;
                uv += _BTexture_ST.zw;
#endif

                col = lerp(col, _BInColor * tex2D(_BTexture, uv), bCircle);
                
                uv = i.uv;
                uv.x *= _CScale;
                uv.x += _CScale * -.75 + .5;
                float cCircle = circle(uv, .5, _CRadius, _CSmooth);
                col = lerp(col, _CColor, cCircle);

                col.rgb = col.rgb * i.lightColor.rgb + i.specularColor.rgb;
#if _RIMTOGGLE_ON
                col = lerp(col, _RimColor, i.rimColor);
#endif

                return col;
            }
            ENDCG
        }
    }
}
