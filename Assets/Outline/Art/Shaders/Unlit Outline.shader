Shader "Universal Render Pipeline/Unlit Outline"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OutlineWidth ("Width", Float ) = 0.5
        [HDR] _OutlineColor ("Color", Color) = (0.0,0.0,0.0,1.0)
        [Enum(Normal,0,Origin,1)] _OutlineExtrudeMethod("Outline Extrude Method", int) = 0
        _OutlineOffset ("Outline Offset", Vector) = (0,0,0)
        _OutlineZPostionInCamera ("Outline Z Position In Camera", Float) = 0.0
        [ToggleOff] _AlphaBaseCutout ("Alpha Base Cutout", Float ) = 1.0
        _Cutout ("Cutout", Range(0, 1)) = 0.0
    }

    SubShader
    {

        Tags
        {
            "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }


        Pass
        {

            Name"Outline"
            Tags
            {
                "LightMode"="SRPDefaultUnlit"
            }


            Cull Front

            HLSLPROGRAM
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float4 vertexColor : COLOR;
                float2 uvLM : TEXCOORD1;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionWSAndFogFactor : TEXCOORD2;
                float4 projPos : TEXCOORD7;
                float4 posWorld : TEXCOORD8;
                float4 vertexColor : COLOR;
                float4 positionCS : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            

            CBUFFER_START(UnityPerMaterial)
                uniform float4 _MainTex_ST;
                uniform half _OutlineWidth;
                uniform int _OutlineExtrudeMethod;
                uniform half3 _OutlineOffset;
                uniform half _OutlineZPostionInCamera;
                uniform half _Cutout;
                uniform half _AlphaBaseCutout;
                uniform half4 _OutlineColor;
            CBUFFER_END


            Varyings LitPassVertex(Attributes input)
            {
                Varyings output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.vertexColor = input.vertexColor;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                float2 _1283_skew = output.uv + 0.2127 + output.uv.x * 0.3713 * output.uv.y;
                float2 _1283_rnd = 4.789 * sin(489.123 * _1283_skew);
                half _1283 = frac(_1283_rnd.x * _1283_rnd.y * (1 + _1283_skew.x));

                float3 _OEM;

                // Normal과 Origin 중 선택
                if (!_OutlineExtrudeMethod)
                    _OEM = input.normalOS;
                else
                    _OEM = normalize(input.positionOS.xyz);

                half RTD_OL = _OutlineWidth * 0.01;

                output.positionCS = mul(GetWorldToHClipMatrix(),
                                        mul(GetObjectToWorldMatrix(),
   float4(
       input.positionOS.xyz + _OutlineOffset.xyz *
       0.01 + _OEM * RTD_OL,
       1.0)));

                output.positionCS.z -= _OutlineZPostionInCamera * 0.0005;

                output.posWorld = float4(vertexInput.positionWS, 1.0);
                output.projPos = ComputeScreenPos(output.positionCS);
                float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);

                return output;
            }

            void LitPassFragment(Varyings input, out half4 outColor : SV_Target0)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half3 color = 1.0;


                half4 _MainTex_var = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);


                half A = _MainTex_var.r + lerp(0.5, -1.0, _Cutout);
                half B = saturate(1.0 - _Cutout > 0.5
                                     ? 1.0 - (1.0 - 2.0 * (1.0 - _Cutout - 0.5)) * (1.0 - _MainTex_var.a)
                                     : 2.0 * (1.0 - _Cutout) *
                                     _MainTex_var.a);

                half alphaClipThreshold = lerp(A, B, _AlphaBaseCutout);

                clip(alphaClipThreshold - 0.5);


                float fogFactor = input.positionWSAndFogFactor.w;

                #ifdef UNITY_COLORSPACE_GAMMA
				_OutlineColor = float4(LinearToGamma22(_OutlineColor.rgb), _OutlineColor.a);
                #endif

                half3 finalRGBA = _OutlineColor.rgb;
                color = MixFog(finalRGBA, fogFactor);

                outColor = half4(color, 1);
            }
            ENDHLSL
        }

        Pass
        {

            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma only_renderers d3d9 d3d11 vulkan glcore gles3 gles metal xboxone ps4 xboxseries playstation switch
            #pragma target 2.0 //targetfl

            #pragma vertex vert;
            #pragma fragment frag;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                return o;
            }

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainColor;
            CBUFFER_END

            float4 frag(Varyings i) : SV_Target
            {
                half4 _MainTex_var = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                clip(_MainTex_var.a - 0.5);
                return _MainTex_var;
            }
            ENDHLSL

        }


    }

    FallBack "Hidden/InternalErrorShader"

}