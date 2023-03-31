Shader "Moein/Unlit/Eyeball"
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
        _BInSmooth("Smoothness In", Range(0, 0.5))= 1
        _BOutSmooth("Smoothness Out", Range(0, 0.5))= 1
        _BRadius("Radius", Range(0,.2))= 1
        _BScale("Scale", Range(0, 10))= 1
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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
#if _RIMTOGGLE_ON
                float3 normal: NORMAL;
#endif
            };

            struct v2f
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
#if _RIMTOGGLE_ON
                float4 rimColor : COLOR0;
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

#if _RIMTOGGLE_ON
            float _RimPower;
            float4 _RimColor;
#endif
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

#if _RIMTOGGLE_ON
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 viewDir = normalize(WorldSpaceViewDir(v.vertex)).xyz;
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
#if _RIMTOGGLE_ON
                col = lerp(col, _RimColor, i.rimColor);
#endif

                return col;
            }
            ENDCG
        }
    }
}