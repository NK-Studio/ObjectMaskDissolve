Shader "Universal Render Pipeline/Lit Dissolve Outline"
{
    Properties
    {
        [HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
        [Toggle(BOOLEAN_USE_WROLDSPACE_ON)] BOOLEAN_USE_WROLDSPACE("UseWorldSpace", Float) = 0
        [Toggle(BOOLEAN_WORLDORIGIN_ON)] BOOLEAN_WORLDORIGIN("WorldSpaceOffset", Float) = 0
        _BaseMap("BaseMap", 2D) = "white" {}
        [Gamma]_BaseColor("BaseColor", Color) = (1,1,1,1)
        [Normal]_BumpMap("BumpMap", 2D) = "bump" {}
        _BumpScale("BumpScale", Float) = 1
        _ParallaxMap("Height Map", 2D) = "black" {}
        _Parallax("Scale", Range( 0.005 , 0.08)) = 0.08
        _OcclusionMap("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength("Strength", Range( 0 , 1)) = 1
        _MetallicGlossMap("MetallicGlossMap", 2D) = "white" {}
        _Metallic("Metallic", Range( 0 , 1)) = 0
        _SmoothnessTextureChannel("_SmoothnessTextureChannel", Float) = 0
        _Smoothness("Smoothness", Range( 0 , 1)) = 0.5
        [Toggle(_EMISSION)] _UseEmission("Use Emission", Float) = 0
        _EmissionMap("EmissionMap", 2D) = "white" {}
        [HDR]_EmissionColor("EmissionColor", Color) = (0,0,0,0)
        [Toggle]_AlphaClip("__clip", Float) = 0

        // Dissolve
        _EdgeWidth("EdgeWidth", Range( 0 , 1)) = 0.05
        [HDR]_EdgeColor("EdgeColor", Color) = (0,2.917647,2.980392,1)
        _DirectionEdgeWidthScale("DirectionEdgeWidthScale", Float) = 10
        _EdgeColorIntensity("EdgeColorIntensity", Float) = 1
        _NoiseScale("NoiseScale", Float) = 50
        _DissolveOffset("DissolveOffset", Vector) = (0,0,0,0)
        [Toggle(BOOLEAN_DIRECTION_FROM_EULERANGLE_ON)] BOOLEAN_DIRECTION_FROM_EULERANGLE("DissolveDirection Is EulerAngle", Float) = 0
        _DissolveDirection("Dissolve Direction", Vector) = (0,0.1,0,0)
        _NoiseUVSpeed("NoiseUVSpeed", Vector) = (1,1,0,0)

        // Outline
        _OutlineWidth ("Width", Float ) = 0.5
        [HDR] _OutlineColor ("Color", Color) = (0.0,0.0,0.0,1.0)
        [Enum(Normal,0,Origin,1)] _OutlineExtrudeMethod("Outline Extrude Method", int) = 0
        _OutlineOffset ("Outline Offset", Vector) = (0,0,0)
        _OutlineZPostionInCamera ("Outline Z Position In Camera", Float) = 0.0
        [ToggleOff] _AlphaBaseCutout ("Alpha Base Cutout", Float ) = 1.0

        [HideInInspector][ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [HideInInspector][ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [HideInInspector][ToggleOff] _ReceiveShadows("Receive Shadows", Float) = 1.0

        [HideInInspector] _QueueOffset("_QueueOffset", Float) = 0
        [HideInInspector] _QueueControl("_QueueControl", Float) = -1

        [HideInInspector][NoScaleOffset] unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }

    SubShader
    {
        LOD 0



        Tags
        {
            "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "UniversalMaterialType"="Lit"
        }

        Cull Back
        ZWrite On
        ZTest LEqual
        Offset 0 , 0
        AlphaToMask Off



        HLSLINCLUDE
        #pragma target 4.5
        #pragma prefer_hlslcc gles
        // ensure rendering platforms toggle list is visible

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

        #ifndef ASE_TESS_FUNCS
        #define ASE_TESS_FUNCS

        float4 FixedTess(float tessValue)
        {
            return tessValue;
        }

        float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess, float4x4 o2w,
                                     float3 cameraPos)
        {
            float3 wpos = mul(o2w, vertex).xyz;
            float dist = distance(wpos, cameraPos);
            float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
            return f;
        }

        float4 CalcTriEdgeTessFactors(float3 triVertexFactors)
        {
            float4 tess;
            tess.x = 0.5 * (triVertexFactors.y + triVertexFactors.z);
            tess.y = 0.5 * (triVertexFactors.x + triVertexFactors.z);
            tess.z = 0.5 * (triVertexFactors.x + triVertexFactors.y);
            tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
            return tess;
        }

        float CalcEdgeTessFactor(float3 wpos0, float3 wpos1, float edgeLen, float3 cameraPos, float4 scParams)
        {
            float dist = distance(0.5 * (wpos0 + wpos1), cameraPos);
            float len = distance(wpos0, wpos1);
            float f = max(len * scParams.y / (edgeLen * dist), 1.0);
            return f;
        }

        float DistanceFromPlane(float3 pos, float4 plane)
        {
            float d = dot(float4(pos, 1.0f), plane);
            return d;
        }

        bool WorldViewFrustumCull(float3 wpos0, float3 wpos1, float3 wpos2, float cullEps, float4 planes[6])
        {
            float4 planeTest;
            planeTest.x = ((DistanceFromPlane(wpos0, planes[0]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos1, planes[0]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos2, planes[0]) > -cullEps) ? 1.0f : 0.0f);
            planeTest.y = ((DistanceFromPlane(wpos0, planes[1]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos1, planes[1]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos2, planes[1]) > -cullEps) ? 1.0f : 0.0f);
            planeTest.z = ((DistanceFromPlane(wpos0, planes[2]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos1, planes[2]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos2, planes[2]) > -cullEps) ? 1.0f : 0.0f);
            planeTest.w = ((DistanceFromPlane(wpos0, planes[3]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos1, planes[3]) > -cullEps) ? 1.0f : 0.0f) +
                ((DistanceFromPlane(wpos2, planes[3]) > -cullEps) ? 1.0f : 0.0f);
            return !all(planeTest);
        }

        float4 DistanceBasedTess(float4 v0, float4 v1, float4 v2, float tess, float minDist, float maxDist,
                                 float4x4 o2w, float3 cameraPos)
        {
            float3 f;
            f.x = CalcDistanceTessFactor(v0, minDist, maxDist, tess, o2w, cameraPos);
            f.y = CalcDistanceTessFactor(v1, minDist, maxDist, tess, o2w, cameraPos);
            f.z = CalcDistanceTessFactor(v2, minDist, maxDist, tess, o2w, cameraPos);

            return CalcTriEdgeTessFactors(f);
        }

        float4 EdgeLengthBasedTess(float4 v0, float4 v1, float4 v2, float edgeLength, float4x4 o2w, float3 cameraPos,
                                   float4 scParams)
        {
            float3 pos0 = mul(o2w, v0).xyz;
            float3 pos1 = mul(o2w, v1).xyz;
            float3 pos2 = mul(o2w, v2).xyz;
            float4 tess;
            tess.x = CalcEdgeTessFactor(pos1, pos2, edgeLength, cameraPos, scParams);
            tess.y = CalcEdgeTessFactor(pos2, pos0, edgeLength, cameraPos, scParams);
            tess.z = CalcEdgeTessFactor(pos0, pos1, edgeLength, cameraPos, scParams);
            tess.w = (tess.x + tess.y + tess.z) / 3.0f;
            return tess;
        }

        float4 EdgeLengthBasedTessCull(float4 v0, float4 v1, float4 v2, float edgeLength, float maxDisplacement,
                                       float4x4 o2w, float3 cameraPos, float4 scParams,
                                       float4 planes[6])
        {
            float3 pos0 = mul(o2w, v0).xyz;
            float3 pos1 = mul(o2w, v1).xyz;
            float3 pos2 = mul(o2w, v2).xyz;
            float4 tess;

            if (WorldViewFrustumCull(pos0, pos1, pos2, maxDisplacement, planes))
            {
                tess = 0.0f;
            }
            else
            {
                tess.x = CalcEdgeTessFactor(pos1, pos2, edgeLength, cameraPos, scParams);
                tess.y = CalcEdgeTessFactor(pos2, pos0, edgeLength, cameraPos, scParams);
                tess.z = CalcEdgeTessFactor(pos0, pos1, edgeLength, cameraPos, scParams);
                tess.w = (tess.x + tess.y + tess.z) / 3.0f;
            }
            return tess;
        }
        #endif //ASE_TESS_FUNCS
        ENDHLSL


        Pass
        {
            Name"Outline"
            Tags
            {
                "LightMode"="SRPDefaultUnlit"
            }

            ZWrite Off
            Cull Front

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_fog
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            
            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_FRAG_WORLD_POSITION
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float4 clipPos : SV_POSITION;
                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 worldPos : TEXCOORD0;
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD1;
                #endif
                float4 positionWSAndFogFactor : TEXCOORD2;
                float4 ase_texcoord3 : TEXCOORD3;
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                float4 ase_texcoord6 : TEXCOORD6;
                float4 ase_texcoord7 : TEXCOORD7;
                float4 projPos : TEXCOORD8;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;

                half _OutlineWidth;
                int _OutlineExtrudeMethod;
                half3 _OutlineOffset;
                half _OutlineZPostionInCamera;
                half _Cutoff;
                half _AlphaBaseCutout;
                half4 _OutlineColor;

                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_ParallaxMap);
            SAMPLER(sampler_ParallaxMap);

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                o.ase_texcoord4.xyz = ase_worldTangent;

                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                o.ase_texcoord5.xyz = ase_worldNormal;

                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord6.xyz = ase_worldBitangent;

                o.ase_texcoord3.xy = v.ase_texcoord.xy;
                o.ase_texcoord7 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord3.zw = 0;
                o.ase_texcoord4.w = 0;
                o.ase_texcoord5.w = 0;
                o.ase_texcoord6.w = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);

                float3 _OEM;

                // Normal과 Origin 중 선택
                if (!_OutlineExtrudeMethod)
                    _OEM = v.ase_normal;
                else
                    _OEM = normalize(v.vertex.xyz);

                half RTD_OL = _OutlineWidth * 0.01;

                //o.clipPos = positionCS;

                o.clipPos = mul(GetWorldToHClipMatrix(),
                                mul(GetObjectToWorldMatrix(),
  float4(
      v.vertex.xyz + _OutlineOffset.xyz *
      0.01 + _OEM * RTD_OL,
      1.0)));

                o.clipPos.z -= _OutlineZPostionInCamera * 0.0005;
                o.worldPos = float4(vertexInput.positionWS, 1.0).xyz;
                o.projPos = ComputeScreenPos(o.clipPos);
                float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                o.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);

                return o;
            }


            half4 frag(VertexOutput IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 WorldPosition = IN.worldPos;
                #endif

                #if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #endif
                #endif

                float2 uv_BaseMap = IN.ase_texcoord3.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldTangent = IN.ase_texcoord4.xyz;
                float3 ase_worldNormal = IN.ase_texcoord5.xyz;
                float3 ase_worldBitangent = IN.ase_texcoord6.xyz;
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - WorldPosition);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(
                    SAMPLE_TEXTURE2D(_ParallaxMap, sampler_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
				float2 staticSwitch297 = ( uv_BaseMap + paralaxOffset282 );
                #else
                float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 _MainTex_var = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, staticSwitch297);
            	            	
                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord3.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord7.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord7.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
            	
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif
            	
                float Alpha = _MainTex_var.a;
                float AlphaClipThreshold = staticSwitch333 + lerp(0.5, -1.0, _Cutoff);;
            	
                #ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
                #endif
            	
                float fogFactor = IN.positionWSAndFogFactor.w;
                half3 Color = MixFog(_OutlineColor.rgb, fogFactor);

                return half4(Color, 1);
            }
            ENDHLSL
        }


        Pass
        {

            Name "Forward"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            Blend One Zero, One Zero
            ZWrite On
            ZTest LEqual
            Offset 0 , 0
            ColorMask RGBA



            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #define ASE_FOG 1
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _NORMALMAP
            #define ASE_SRP_VERSION 140008


            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP // 추가함
            #pragma shader_feature_local _PARALLAXMAP // 추가함
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 추가됨

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS

            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS

            #pragma vertex vert
            #pragma fragment frag

            #define SHADERPASS SHADERPASS_FORWARD

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
				#define ENABLE_TERRAIN_PERPIXEL_NORMAL
            #endif

            #define ASE_NEEDS_FRAG_WORLD_TANGENT
            #define ASE_NEEDS_FRAG_WORLD_NORMAL
            #define ASE_NEEDS_FRAG_WORLD_BITANGENT
            #define ASE_NEEDS_FRAG_WORLD_VIEW_DIR
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            #if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
            #else
            #define ASE_SV_DEPTH SV_Depth
            #define ASE_SV_POSITION_QUALIFIERS
            #endif

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float4 texcoord2 : TEXCOORD2;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                ASE_SV_POSITION_QUALIFIERS float4 clipPos : SV_POSITION;
                float4 clipPosV : TEXCOORD0;
                float4 lightmapUVOrVertexSH : TEXCOORD1;
                half4 fogFactorAndVertexLight : TEXCOORD2;
                float4 tSpace0 : TEXCOORD3;
                float4 tSpace1 : TEXCOORD4;
                float4 tSpace2 : TEXCOORD5;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					float4 shadowCoord : TEXCOORD6;
                #endif
                #if defined(DYNAMICLIGHTMAP_ON)
					float2 dynamicLightmapUV : TEXCOORD7;
                #endif
                float4 ase_texcoord8 : TEXCOORD8;
                float4 ase_texcoord9 : TEXCOORD9;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;
            sampler2D _BumpMap;
            sampler2D _EmissionMap;
            sampler2D _MetallicGlossMap;
            SAMPLER(sampler_MetallicGlossMap);
            sampler2D _OcclusionMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/PBRForwardPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }

            half4 SampleMetallicSpecGloss(sampler2D tex, SamplerState ss, half2 uv, half albedoAlpha, half metallic,
                                          half smoothness)
            {
                half4 specGloss;

                #ifdef _METALLICSPECGLOSSMAP // 메탈릭 텍스쳐가 바인딩 되어 있다면,
				    specGloss = SAMPLE_TEXTURE2D(tex, ss,  uv);
                #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 베이스맵의 알파를 스무스니스 체널로 사용하는 경우
				        specGloss.a = albedoAlpha * smoothness;
                #else
				        specGloss.a *= smoothness;
                #endif
                #else // 메탈릭 텍스쳐가 바인딩 안되어 있다면,
                specGloss.rgb = metallic.rrr;

                #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 베이스맵의 알파를 스무스니스 체널로 사용하는 경우
				        specGloss.a = albedoAlpha * smoothness;
                #else
                specGloss.a = smoothness;
                #endif
                #endif
                return specGloss;
            }


            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.ase_texcoord8.xy = v.texcoord.xy;
                o.ase_texcoord9 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord8.zw = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif
                v.ase_normal = v.ase_normal;

                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 positionVS = TransformWorldToView(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(v.ase_normal, v.ase_tangent);

                o.tSpace0 = float4(normalInput.normalWS, positionWS.x);
                o.tSpace1 = float4(normalInput.tangentWS, positionWS.y);
                o.tSpace2 = float4(normalInput.bitangentWS, positionWS.z);

                #if defined(LIGHTMAP_ON)
					OUTPUT_LIGHTMAP_UV( v.texcoord1, unity_LightmapST, o.lightmapUVOrVertexSH.xy );
                #endif

                #if !defined(LIGHTMAP_ON)
                OUTPUT_SH(normalInput.normalWS.xyz, o.lightmapUVOrVertexSH.xyz);
                #endif

                #if defined(DYNAMICLIGHTMAP_ON)
					o.dynamicLightmapUV.xy = v.texcoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif

                #if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					o.lightmapUVOrVertexSH.zw = v.texcoord.xy;
					o.lightmapUVOrVertexSH.xy = v.texcoord.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                half3 vertexLight = VertexLighting(positionWS, normalInput.normalWS);

                #ifdef ASE_FOG
                half fogFactor = ComputeFogFactor(positionCS.z);
                #else
					half fogFactor = 0;
                #endif

                o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                o.clipPos = positionCS;
                o.clipPosV = positionCS;
                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }

            half4 frag(VertexOutput IN
                #ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
                #endif
                #ifdef _WRITE_RENDERING_LAYERS
						, out float4 outRenderingLayers : SV_Target1
                #endif
            ) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.clipPos );
                #endif

                #if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float2 sampleCoords = (IN.lightmapUVOrVertexSH.zw / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
					float3 WorldNormal = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
					float3 WorldTangent = -cross(GetObjectToWorldMatrix()._13_23_33, WorldNormal);
					float3 WorldBiTangent = cross(WorldNormal, -WorldTangent);
                #else
                float3 WorldNormal = normalize(IN.tSpace0.xyz);
                float3 WorldTangent = IN.tSpace1.xyz;
                float3 WorldBiTangent = IN.tSpace2.xyz;
                #endif

                float3 WorldPosition = float3(IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w);
                float3 WorldViewDirection = _WorldSpaceCameraPos.xyz - WorldPosition;
                float4 ShadowCoords = float4(0, 0, 0, 0);

                float4 ClipPos = IN.clipPosV;
                float4 ScreenPos = ComputeScreenPos(IN.clipPosV);

                float2 NormalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.clipPos);

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #endif

                WorldViewDirection = SafeNormalize(WorldViewDirection);

                float2 uv_BaseMap = IN.ase_texcoord8.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 tanToWorld0 = float3(WorldTangent.x, WorldBiTangent.x, WorldNormal.x);
                float3 tanToWorld1 = float3(WorldTangent.y, WorldBiTangent.y, WorldNormal.y);
                float3 tanToWorld2 = float3(WorldTangent.z, WorldBiTangent.z, WorldNormal.z);
                float3 ase_tanViewDir = tanToWorld0 * WorldViewDirection.x + tanToWorld1 * WorldViewDirection.y +
                    tanToWorld2 * WorldViewDirection.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
                float2 staticSwitch297 = (uv_BaseMap + paralaxOffset282);
                #else
				float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);

                float3 unpack21 = UnpackNormalScale(tex2D(_BumpMap, staticSwitch297), _BumpScale);
                unpack21.z = lerp(1, unpack21.z, saturate(_BumpScale));
                #ifdef _NORMALMAP
                float3 staticSwitch223 = unpack21;
                #else
				float3 staticSwitch223 = float3(0,0,1);
                #endif
                float3 Normal77 = staticSwitch223;

                #ifdef _EMISSION
				float3 staticSwitch182 = ( (_EmissionColor).rgb * (tex2D( _EmissionMap, staticSwitch297 )).rgb );
                #else
                float3 staticSwitch182 = float3(0, 0, 0);
                #endif
                float3 Emissive104 = staticSwitch182;
                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord8.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord9.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord9.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float lerpResult9_g6 = lerp(0.0, (1.0 + temp_output_2_0_g6), temp_output_1_0_g6);
                #ifdef _ALPHATEST_ON
				float4 staticSwitch388 = ( ( ( temp_output_7_0_g6 - step( lerpResult9_g6 , temp_output_3_0_g6 ) ) * _EdgeColor ) * _EdgeColorIntensity );
                #else
                float4 staticSwitch388 = float4(Emissive104, 0.0);
                #endif

                sampler2D tex244 = _MetallicGlossMap;
                SamplerState ss244 = sampler_MetallicGlossMap;
                half2 uv244 = staticSwitch297;
                float BaseAlpha175 = tex2DNode10.a;
                half albedoAlpha244 = BaseAlpha175;
                half metallic244 = _Metallic;
                half smoothness244 = _Smoothness;
                half4 localSampleMetallicSpecGloss244 = SampleMetallicSpecGloss(
                    tex244, ss244, uv244, albedoAlpha244, metallic244, smoothness244);
                float Metallic79 = ((localSampleMetallicSpecGloss244).xyz).x;

                float Smoothness116 = (localSampleMetallicSpecGloss244).w;

                float3 temp_cast_2 = (tex2D(_OcclusionMap, staticSwitch297).g).xxx;
                float temp_output_2_0_g2 = _OcclusionStrength;
                float temp_output_3_0_g2 = (1.0 - temp_output_2_0_g2);
                float3 appendResult7_g2 = (float3(temp_output_3_0_g2, temp_output_3_0_g2, temp_output_3_0_g2));
                float AO81 = (((temp_cast_2 * temp_output_2_0_g2) + appendResult7_g2)).x;

                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                float3 BaseColor = (BaseMap89).rgb;
                float3 Normal = Normal77;
                float3 Emission = staticSwitch388.rgb;
                float3 Specular = 0.5;
                float Metallic = Metallic79;
                float Smoothness = Smoothness116;
                float Occlusion = AO81;
                float Alpha = temp_output_206_0;
                float AlphaClipThreshold = staticSwitch333;
                float AlphaClipThresholdShadow = 0.5;
                float3 BakedGI = 0;
                float3 RefractionColor = 1;
                float RefractionIndex = 1;
                float3 Transmission = 1;
                float3 Translucency = 1;

                #ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = IN.clipPos.z;
                #endif

                #ifdef _CLEARCOAT
					float CoatMask = 0;
					float CoatSmoothness = 0;
                #endif

                #ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
                #endif

                InputData inputData = (InputData)0;
                inputData.positionWS = WorldPosition;
                inputData.viewDirectionWS = WorldViewDirection;

                #ifdef _NORMALMAP
                #if _NORMAL_DROPOFF_TS
                inputData.normalWS =
                    TransformTangentToWorld(Normal, half3x3(WorldTangent, WorldBiTangent, WorldNormal));
                #elif _NORMAL_DROPOFF_OS
							inputData.normalWS = TransformObjectToWorldNormal(Normal);
                #elif _NORMAL_DROPOFF_WS
							inputData.normalWS = Normal;
                #endif
                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                #else
					inputData.normalWS = WorldNormal;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					inputData.shadowCoord = ShadowCoords;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif

                #ifdef ASE_FOG
                inputData.fogCoord = IN.fogFactorAndVertexLight.x;
                #endif
                inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;

                #if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float3 SH = SampleSH(inputData.normalWS.xyz);
                #else
                float3 SH = IN.lightmapUVOrVertexSH.xyz;
                #endif

                #if defined(DYNAMICLIGHTMAP_ON)
					inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy, IN.dynamicLightmapUV.xy, SH, inputData.normalWS);
                #else
                inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy, SH, inputData.normalWS);
                #endif

                #ifdef ASE_BAKEDGI
					inputData.bakedGI = BakedGI;
                #endif

                inputData.normalizedScreenSpaceUV = NormalizedScreenSpaceUV;
                inputData.shadowMask = SAMPLE_SHADOWMASK(IN.lightmapUVOrVertexSH.xy);

                #if defined(DEBUG_DISPLAY)
                #if defined(DYNAMICLIGHTMAP_ON)
						inputData.dynamicLightmapUV = IN.dynamicLightmapUV.xy;
                #endif
                #if defined(LIGHTMAP_ON)
						inputData.staticLightmapUV = IN.lightmapUVOrVertexSH.xy;
                #else
						inputData.vertexSH = SH;
                #endif
                #endif

                SurfaceData surfaceData;
                surfaceData.albedo = BaseColor;
                surfaceData.metallic = saturate(Metallic);
                surfaceData.specular = Specular;
                surfaceData.smoothness = saturate(Smoothness),
                    surfaceData.occlusion = Occlusion,
                    surfaceData.emission = Emission,
                    surfaceData.alpha = saturate(Alpha);
                surfaceData.normalTS = Normal;
                surfaceData.clearCoatMask = 0;
                surfaceData.clearCoatSmoothness = 1;

                #ifdef _CLEARCOAT
					surfaceData.clearCoatMask       = saturate(CoatMask);
					surfaceData.clearCoatSmoothness = saturate(CoatSmoothness);
                #endif

                #ifdef _DBUFFER
					ApplyDecalToSurfaceData(IN.clipPos, surfaceData, inputData);
                #endif

                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                #ifdef ASE_TRANSMISSION
				{
					float shadow = _TransmissionShadow;

					#define SUM_LIGHT_TRANSMISSION(Light)\
						float3 atten = Light.color * Light.distanceAttenuation;\
						atten = lerp( atten, atten * Light.shadowAttenuation, shadow );\
						half3 transmission = max( 0, -dot( inputData.normalWS, Light.direction ) ) * atten * Transmission;\
						color.rgb += BaseColor * transmission;

					SUM_LIGHT_TRANSMISSION( GetMainLight( inputData.shadowCoord ) );

                #if defined(_ADDITIONAL_LIGHTS)
						uint meshRenderingLayers = GetMeshRenderingLayer();
						uint pixelLightCount = GetAdditionalLightsCount();
                #if USE_FORWARD_PLUS
							for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
							{
								FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

								Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                #ifdef _LIGHT_LAYERS
								if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
								{
									SUM_LIGHT_TRANSMISSION( light );
								}
							}
                #endif
						LIGHT_LOOP_BEGIN( pixelLightCount )
							Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                #ifdef _LIGHT_LAYERS
							if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
							{
								SUM_LIGHT_TRANSMISSION( light );
							}
						LIGHT_LOOP_END
                #endif
				}
                #endif

                #ifdef ASE_TRANSLUCENCY
				{
					float shadow = _TransShadow;
					float normal = _TransNormal;
					float scattering = _TransScattering;
					float direct = _TransDirect;
					float ambient = _TransAmbient;
					float strength = _TransStrength;

					#define SUM_LIGHT_TRANSLUCENCY(Light)\
						float3 atten = Light.color * Light.distanceAttenuation;\
						atten = lerp( atten, atten * Light.shadowAttenuation, shadow );\
						half3 lightDir = Light.direction + inputData.normalWS * normal;\
						half VdotL = pow( saturate( dot( inputData.viewDirectionWS, -lightDir ) ), scattering );\
						half3 translucency = atten * ( VdotL * direct + inputData.bakedGI * ambient ) * Translucency;\
						color.rgb += BaseColor * translucency * strength;

					SUM_LIGHT_TRANSLUCENCY( GetMainLight( inputData.shadowCoord ) );

                #if defined(_ADDITIONAL_LIGHTS)
						uint meshRenderingLayers = GetMeshRenderingLayer();
						uint pixelLightCount = GetAdditionalLightsCount();
                #if USE_FORWARD_PLUS
							for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
							{
								FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

								Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                #ifdef _LIGHT_LAYERS
								if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
								{
									SUM_LIGHT_TRANSLUCENCY( light );
								}
							}
                #endif
						LIGHT_LOOP_BEGIN( pixelLightCount )
							Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                #ifdef _LIGHT_LAYERS
							if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
							{
								SUM_LIGHT_TRANSLUCENCY( light );
							}
						LIGHT_LOOP_END
                #endif
				}
                #endif

                #ifdef ASE_REFRACTION
					float4 projScreenPos = ScreenPos / ScreenPos.w;
					float3 refractionOffset = ( RefractionIndex - 1.0 ) * mul( UNITY_MATRIX_V, float4( WorldNormal,0 ) ).xyz * ( 1.0 - dot( WorldNormal, WorldViewDirection ) );
					projScreenPos.xy += refractionOffset.xy;
					float3 refraction = SHADERGRAPH_SAMPLE_SCENE_COLOR( projScreenPos.xy ) * RefractionColor;
					color.rgb = lerp( refraction, color.rgb, color.a );
					color.a = 1;
                #endif

                #ifdef ASE_FINAL_COLOR_ALPHA_MULTIPLY
					color.rgb *= color.a;
                #endif

                #ifdef ASE_FOG
                #ifdef TERRAIN_SPLAT_ADDPASS
						color.rgb = MixFogColor(color.rgb, half3( 0, 0, 0 ), IN.fogFactorAndVertexLight.x );
                #else
                color.rgb = MixFog(color.rgb, IN.fogFactorAndVertexLight.x);
                #endif
                #endif

                #ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
                #endif

                #ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4( EncodeMeshRenderingLayer( renderingLayers ), 0, 0, 0 );
                #endif

                return color;
            }
            ENDHLSL
        }


        Pass
        {

            Name "ShadowCaster"
            Tags
            {
                "LightMode"="ShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            AlphaToMask Off
            ColorMask 0

            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #define ASE_SRP_VERSION 140008


            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 추가됨

            #define SHADERPASS SHADERPASS_SHADOWCASTER


            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_FRAG_WORLD_POSITION
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            #if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
            #else
            #define ASE_SV_DEPTH SV_Depth
            #define ASE_SV_POSITION_QUALIFIERS
            #endif

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                ASE_SV_POSITION_QUALIFIERS float4 clipPos : SV_POSITION;
                float4 clipPosV : TEXCOORD0;
                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 worldPos : TEXCOORD1;
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD2;
                #endif
                float4 ase_texcoord3 : TEXCOORD3;
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                float4 ase_texcoord6 : TEXCOORD6;
                float4 ase_texcoord7 : TEXCOORD7;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShadowCasterPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }


            float3 _LightDirection;
            float3 _LightPosition;

            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                o.ase_texcoord4.xyz = ase_worldTangent;
                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                o.ase_texcoord5.xyz = ase_worldNormal;
                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord6.xyz = ase_worldBitangent;

                o.ase_texcoord3.xy = v.ase_texcoord.xy;
                o.ase_texcoord7 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord3.zw = 0;
                o.ase_texcoord4.w = 0;
                o.ase_texcoord5.w = 0;
                o.ase_texcoord6.w = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;
                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;

                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                o.worldPos = positionWS;
                #endif

                float3 normalWS = TransformObjectToWorldDir(v.ase_normal);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
					float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                float3 lightDirectionWS = _LightDirection;
                #endif

                float4 clipPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                clipPos.z = min(clipPos.z, UNITY_NEAR_CLIP_VALUE);
                #else
					clipPos.z = max(clipPos.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = clipPos;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                o.clipPos = clipPos;
                o.clipPosV = clipPos;
                return o;
            }


            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }


            half4 frag(VertexOutput IN
                #ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
                #endif
            ) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 WorldPosition = IN.worldPos;
                #endif

                float4 ShadowCoords = float4(0, 0, 0, 0);
                float4 ClipPos = IN.clipPosV;
                float4 ScreenPos = ComputeScreenPos(IN.clipPosV);

                #if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #endif
                #endif

                float2 uv_BaseMap = IN.ase_texcoord3.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldTangent = IN.ase_texcoord4.xyz;
                float3 ase_worldNormal = IN.ase_texcoord5.xyz;
                float3 ase_worldBitangent = IN.ase_texcoord6.xyz;
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - WorldPosition);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
				float2 staticSwitch297 = ( uv_BaseMap + paralaxOffset282 );
                #else
                float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);
                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord3.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord7.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord7.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                float Alpha = temp_output_206_0;
                float AlphaClipThreshold = staticSwitch333;
                float AlphaClipThresholdShadow = 0.5;

                #ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = IN.clipPos.z;
                #endif

                #ifdef _ALPHATEST_ON
                #ifdef _ALPHATEST_SHADOW_ON
						clip(Alpha - AlphaClipThresholdShadow);
                #else
						clip(Alpha - AlphaClipThreshold);
                #endif
                #endif

                #ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.clipPos );
                #endif

                #ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
                #endif

                return 0;
            }
            ENDHLSL
        }


        Pass
        {

            Name "DepthOnly"
            Tags
            {
                "LightMode"="DepthOnly"
            }

            ZWrite On
            ColorMask R
            AlphaToMask Off

            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #define ASE_SRP_VERSION 140008


            #pragma vertex vert
            #pragma fragment frag

            #define SHADERPASS SHADERPASS_DEPTHONLY
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 추가됨

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_FRAG_WORLD_POSITION
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            #if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
            #else
            #define ASE_SV_DEPTH SV_Depth
            #define ASE_SV_POSITION_QUALIFIERS
            #endif

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                ASE_SV_POSITION_QUALIFIERS float4 clipPos : SV_POSITION;
                float4 clipPosV : TEXCOORD0;
                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 worldPos : TEXCOORD1;
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
				float4 shadowCoord : TEXCOORD2;
                #endif
                float4 ase_texcoord3 : TEXCOORD3;
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                float4 ase_texcoord6 : TEXCOORD6;
                float4 ase_texcoord7 : TEXCOORD7;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/DepthOnlyPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }


            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                o.ase_texcoord4.xyz = ase_worldTangent;
                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                o.ase_texcoord5.xyz = ase_worldNormal;
                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord6.xyz = ase_worldBitangent;

                o.ase_texcoord3.xy = v.ase_texcoord.xy;
                o.ase_texcoord7 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord3.zw = 0;
                o.ase_texcoord4.w = 0;
                o.ase_texcoord5.w = 0;
                o.ase_texcoord6.w = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float4 positionCS = TransformWorldToHClip(positionWS);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                o.worldPos = positionWS;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                o.clipPos = positionCS;
                o.clipPosV = positionCS;
                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }

            half4 frag(VertexOutput IN
                #ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
                #endif
            ) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 WorldPosition = IN.worldPos;
                #endif

                float4 ShadowCoords = float4(0, 0, 0, 0);
                float4 ClipPos = IN.clipPosV;
                float4 ScreenPos = ComputeScreenPos(IN.clipPosV);

                #if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #endif
                #endif

                float2 uv_BaseMap = IN.ase_texcoord3.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldTangent = IN.ase_texcoord4.xyz;
                float3 ase_worldNormal = IN.ase_texcoord5.xyz;
                float3 ase_worldBitangent = IN.ase_texcoord6.xyz;
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - WorldPosition);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
				float2 staticSwitch297 = ( uv_BaseMap + paralaxOffset282 );
                #else
                float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);
                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord3.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord7.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord7.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                float Alpha = temp_output_206_0;
                float AlphaClipThreshold = staticSwitch333;
                #ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = IN.clipPos.z;
                #endif

                #ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
                #endif

                #ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.clipPos );
                #endif

                #ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
                #endif

                return 0;
            }
            ENDHLSL
        }


        Pass
        {

            Name "Meta"
            Tags
            {
                "LightMode"="Meta"
            }

            Cull Off

            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #define ASE_FOG 1
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #define ASE_SRP_VERSION 140008


            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature EDITOR_VISUALIZATION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP // 추가함
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 추가됨

            #define SHADERPASS SHADERPASS_META

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_FRAG_WORLD_POSITION
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 texcoord0 : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float4 texcoord2 : TEXCOORD2;
                float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float4 clipPos : SV_POSITION;
                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 worldPos : TEXCOORD0;
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD1;
                #endif
                #ifdef EDITOR_VISUALIZATION
                float4 VizUV : TEXCOORD2;
                float4 LightCoord : TEXCOORD3;
                #endif
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                float4 ase_texcoord6 : TEXCOORD6;
                float4 ase_texcoord7 : TEXCOORD7;
                float4 ase_texcoord8 : TEXCOORD8;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;
            sampler2D _EmissionMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/LightingMetaPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }


            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                o.ase_texcoord5.xyz = ase_worldTangent;
                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                o.ase_texcoord6.xyz = ase_worldNormal;
                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord7.xyz = ase_worldBitangent;

                o.ase_texcoord4.xy = v.texcoord0.xy;
                o.ase_texcoord8 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord4.zw = 0;
                o.ase_texcoord5.w = 0;
                o.ase_texcoord6.w = 0;
                o.ase_texcoord7.w = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;

                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                o.worldPos = positionWS;
                #endif

                o.clipPos = MetaVertexPosition(v.vertex, v.texcoord1.xy, v.texcoord1.xy, unity_LightmapST,
                                               unity_DynamicLightmapST);

                #ifdef EDITOR_VISUALIZATION
                float2 VizUV = 0;
                float4 LightCoord = 0;
                UnityEditorVizData(v.vertex.xyz, v.texcoord0.xy, v.texcoord1.xy, v.texcoord2.xy, VizUV, LightCoord);
                o.VizUV = float4(VizUV, 0, 0);
                o.LightCoord = LightCoord;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = o.clipPos;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }

            half4 frag(VertexOutput IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 WorldPosition = IN.worldPos;
                #endif

                float4 ShadowCoords = float4(0, 0, 0, 0);

                #if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #endif
                #endif

                float2 uv_BaseMap = IN.ase_texcoord4.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldTangent = IN.ase_texcoord5.xyz;
                float3 ase_worldNormal = IN.ase_texcoord6.xyz;
                float3 ase_worldBitangent = IN.ase_texcoord7.xyz;
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - WorldPosition);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
				float2 staticSwitch297 = ( uv_BaseMap + paralaxOffset282 );
                #else
                float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);

                #ifdef _EMISSION
				float3 staticSwitch182 = ( (_EmissionColor).rgb * (tex2D( _EmissionMap, staticSwitch297 )).rgb );
                #else
                float3 staticSwitch182 = float3(0, 0, 0);
                #endif
                float3 Emissive104 = staticSwitch182;
                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord4.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord8.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord8.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float lerpResult9_g6 = lerp(0.0, (1.0 + temp_output_2_0_g6), temp_output_1_0_g6);
                #ifdef _ALPHATEST_ON
				float4 staticSwitch388 = ( ( ( temp_output_7_0_g6 - step( lerpResult9_g6 , temp_output_3_0_g6 ) ) * _EdgeColor ) * _EdgeColorIntensity );
                #else
                float4 staticSwitch388 = float4(Emissive104, 0.0);
                #endif

                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                float3 BaseColor = (BaseMap89).rgb;
                float3 Emission = staticSwitch388.rgb;
                float Alpha = temp_output_206_0;
                float AlphaClipThreshold = staticSwitch333;

                #ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
                #endif

                MetaInput metaInput = (MetaInput)0;
                metaInput.Albedo = BaseColor;
                metaInput.Emission = Emission;
                #ifdef EDITOR_VISUALIZATION
                metaInput.VizUV = IN.VizUV.xy;
                metaInput.LightCoord = IN.LightCoord;
                #endif

                return UnityMetaFragment(metaInput);
            }
            ENDHLSL
        }


        Pass
        {

            Name "Universal2D"
            Tags
            {
                "LightMode"="Universal2D"
            }

            Blend One Zero, One Zero
            ZWrite On
            ZTest LEqual
            Offset 0 , 0
            ColorMask RGBA

            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #define ASE_FOG 1
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #define ASE_SRP_VERSION 140008


            #pragma vertex vert
            #pragma fragment frag

            #define SHADERPASS SHADERPASS_2D

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_FRAG_WORLD_POSITION
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float4 clipPos : SV_POSITION;
                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 worldPos : TEXCOORD0;
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD1;
                #endif
                float4 ase_texcoord2 : TEXCOORD2;
                float4 ase_texcoord3 : TEXCOORD3;
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                float4 ase_texcoord6 : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/PBR2DPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }


            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                o.ase_texcoord3.xyz = ase_worldTangent;
                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                o.ase_texcoord4.xyz = ase_worldNormal;
                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord5.xyz = ase_worldBitangent;

                o.ase_texcoord2.xy = v.ase_texcoord.xy;
                o.ase_texcoord6 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord2.zw = 0;
                o.ase_texcoord3.w = 0;
                o.ase_texcoord4.w = 0;
                o.ase_texcoord5.w = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;

                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float4 positionCS = TransformWorldToHClip(positionWS);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                o.worldPos = positionWS;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                o.clipPos = positionCS;

                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }


            half4 frag(VertexOutput IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 WorldPosition = IN.worldPos;
                #endif

                float4 ShadowCoords = float4(0, 0, 0, 0);

                #if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #endif
                #endif

                float2 uv_BaseMap = IN.ase_texcoord2.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldTangent = IN.ase_texcoord3.xyz;
                float3 ase_worldNormal = IN.ase_texcoord4.xyz;
                float3 ase_worldBitangent = IN.ase_texcoord5.xyz;
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - WorldPosition);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
				float2 staticSwitch297 = ( uv_BaseMap + paralaxOffset282 );
                #else
                float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);

                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord2.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord6.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord6.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                float3 BaseColor = (BaseMap89).rgb;
                float Alpha = temp_output_206_0;
                float AlphaClipThreshold = staticSwitch333;

                half4 color = half4(BaseColor, Alpha);

                #ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
                #endif

                return color;
            }
            ENDHLSL
        }


        Pass
        {

            Name "DepthNormals"
            Tags
            {
                "LightMode"="DepthNormals"
            }

            ZWrite On
            Blend One Zero
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _NORMALMAP
            #define ASE_SRP_VERSION 140008


            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
            #pragma shader_feature_local _PARALLAXMAP // 추가함
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 추가됨

            #define SHADERPASS SHADERPASS_DEPTHNORMALSONLY

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #define ASE_NEEDS_FRAG_WORLD_TANGENT
            #define ASE_NEEDS_FRAG_WORLD_NORMAL
            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_VERT_TANGENT
            #define ASE_NEEDS_FRAG_WORLD_POSITION
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            #if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
            #else
            #define ASE_SV_DEPTH SV_Depth
            #define ASE_SV_POSITION_QUALIFIERS
            #endif

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_tangent : TANGENT;
                float4 ase_texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                ASE_SV_POSITION_QUALIFIERS float4 clipPos : SV_POSITION;
                float4 clipPosV : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float4 worldTangent : TEXCOORD2;
                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 worldPos : TEXCOORD3;
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD4;
                #endif
                float4 ase_texcoord5 : TEXCOORD5;
                float4 ase_texcoord6 : TEXCOORD6;
                float4 ase_texcoord7 : TEXCOORD7;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BumpMap;
            sampler2D _BaseMap;
            sampler2D _ParallaxMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/DepthNormalsOnlyPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }


            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord6.xyz = ase_worldBitangent;

                o.ase_texcoord5.xy = v.ase_texcoord.xy;
                o.ase_texcoord7 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord5.zw = 0;
                o.ase_texcoord6.w = 0;
                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 normalWS = TransformObjectToWorldNormal(v.ase_normal);
                float4 tangentWS = float4(TransformObjectToWorldDir(v.ase_tangent.xyz), v.ase_tangent.w);
                float4 positionCS = TransformWorldToHClip(positionWS);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                o.worldPos = positionWS;
                #endif

                o.worldNormal = normalWS;
                o.worldTangent = tangentWS;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                o.clipPos = positionCS;
                o.clipPosV = positionCS;
                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }

            void frag(VertexOutput IN
                      , out half4 outNormalWS : SV_Target0
                      #ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
                      #endif
                      #ifdef _WRITE_RENDERING_LAYERS
						, out float4 outRenderingLayers : SV_Target1
                      #endif
            )
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
                float3 WorldPosition = IN.worldPos;
                #endif

                float4 ShadowCoords = float4(0, 0, 0, 0);
                float3 WorldNormal = IN.worldNormal;
                float4 WorldTangent = IN.worldTangent;

                float4 ClipPos = IN.clipPosV;
                float4 ScreenPos = ComputeScreenPos(IN.clipPosV);

                #if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #endif
                #endif

                float2 uv_BaseMap = IN.ase_texcoord5.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldBitangent = IN.ase_texcoord6.xyz;
                float3 tanToWorld0 = float3(WorldTangent.xyz.x, ase_worldBitangent.x, WorldNormal.x);
                float3 tanToWorld1 = float3(WorldTangent.xyz.y, ase_worldBitangent.y, WorldNormal.y);
                float3 tanToWorld2 = float3(WorldTangent.xyz.z, ase_worldBitangent.z, WorldNormal.z);
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - WorldPosition);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
                float2 staticSwitch297 = (uv_BaseMap + paralaxOffset282);
                #else
				float2 staticSwitch297 = uv_BaseMap;
                #endif
                float3 unpack21 = UnpackNormalScale(tex2D(_BumpMap, staticSwitch297), _BumpScale);
                unpack21.z = lerp(1, unpack21.z, saturate(_BumpScale));
                #ifdef _NORMALMAP
                float3 staticSwitch223 = unpack21;
                #else
				float3 staticSwitch223 = float3(0,0,1);
                #endif
                float3 Normal77 = staticSwitch223;

                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);
                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord5.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord7.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord7.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                float3 Normal = Normal77;
                float Alpha = temp_output_206_0;
                float AlphaClipThreshold = staticSwitch333;
                #ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = IN.clipPos.z;
                #endif

                #ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
                #endif

                #ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.clipPos );
                #endif

                #ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
                #endif

                #if defined(_GBUFFER_NORMALS_OCT)
					float2 octNormalWS = PackNormalOctQuadEncode(WorldNormal);
					float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
					half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
					outNormalWS = half4(packedNormalWS, 0.0);
                #else
                #if defined(_NORMALMAP)
                #if _NORMAL_DROPOFF_TS
                float crossSign = (WorldTangent.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
                float3 bitangent = crossSign * cross(WorldNormal.xyz, WorldTangent.xyz);
                float3 normalWS =
                    TransformTangentToWorld(Normal, half3x3(WorldTangent.xyz, bitangent, WorldNormal.xyz));
                #elif _NORMAL_DROPOFF_OS
							float3 normalWS = TransformObjectToWorldNormal(Normal);
                #elif _NORMAL_DROPOFF_WS
							float3 normalWS = Normal;
                #endif
                #else
						float3 normalWS = WorldNormal;
                #endif
                outNormalWS = half4(NormalizeNormalPerPixel(normalWS), 0.0);
                #endif

                #ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4( EncodeMeshRenderingLayer( renderingLayers ), 0, 0, 0 );
                #endif
            }
            ENDHLSL
        }


        Pass
        {

            Name "GBuffer"
            Tags
            {
                "LightMode"="UniversalGBuffer"
            }

            Blend One Zero, One Zero
            ZWrite On
            ZTest LEqual
            Offset 0 , 0
            ColorMask RGBA


            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #define ASE_FOG 1
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _NORMALMAP
            #define ASE_SRP_VERSION 140008


            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP // 추가함
            #pragma shader_feature_local _PARALLAXMAP // 추가함
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 추가됨

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS

            #pragma vertex vert
            #pragma fragment frag

            #define SHADERPASS SHADERPASS_GBUFFER

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
				#define ENABLE_TERRAIN_PERPIXEL_NORMAL
            #endif

            #define ASE_NEEDS_FRAG_WORLD_TANGENT
            #define ASE_NEEDS_FRAG_WORLD_NORMAL
            #define ASE_NEEDS_FRAG_WORLD_BITANGENT
            #define ASE_NEEDS_FRAG_WORLD_VIEW_DIR
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            #if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
            #else
            #define ASE_SV_DEPTH SV_Depth
            #define ASE_SV_POSITION_QUALIFIERS
            #endif

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float4 texcoord2 : TEXCOORD2;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                ASE_SV_POSITION_QUALIFIERS float4 clipPos : SV_POSITION;
                float4 clipPosV : TEXCOORD0;
                float4 lightmapUVOrVertexSH : TEXCOORD1;
                half4 fogFactorAndVertexLight : TEXCOORD2;
                float4 tSpace0 : TEXCOORD3;
                float4 tSpace1 : TEXCOORD4;
                float4 tSpace2 : TEXCOORD5;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
				float4 shadowCoord : TEXCOORD6;
                #endif
                #if defined(DYNAMICLIGHTMAP_ON)
				float2 dynamicLightmapUV : TEXCOORD7;
                #endif
                float4 ase_texcoord8 : TEXCOORD8;
                float4 ase_texcoord9 : TEXCOORD9;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;
            sampler2D _BumpMap;
            sampler2D _EmissionMap;
            sampler2D _MetallicGlossMap;
            SAMPLER(sampler_MetallicGlossMap);
            sampler2D _OcclusionMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/PBRGBufferPass.hlsl"

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }

            half4 SampleMetallicSpecGloss(sampler2D tex, SamplerState ss, half2 uv, half albedoAlpha, half metallic,
                                          half smoothness)
            {
                half4 specGloss;

                #ifdef _METALLICSPECGLOSSMAP // 메탈릭 텍스쳐가 바인딩 되어 있다면,
				    specGloss = SAMPLE_TEXTURE2D(tex, ss,  uv);
                #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 베이스맵의 알파를 스무스니스 체널로 사용하는 경우
				        specGloss.a = albedoAlpha * smoothness;
                #else
				        specGloss.a *= smoothness;
                #endif
                #else // 메탈릭 텍스쳐가 바인딩 안되어 있다면,
                specGloss.rgb = metallic.rrr;

                #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 베이스맵의 알파를 스무스니스 체널로 사용하는 경우
				        specGloss.a = albedoAlpha * smoothness;
                #else
                specGloss.a = smoothness;
                #endif
                #endif
                return specGloss;
            }


            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.ase_texcoord8.xy = v.texcoord.xy;
                o.ase_texcoord9 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord8.zw = 0;
                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;

                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 positionVS = TransformWorldToView(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(v.ase_normal, v.ase_tangent);

                o.tSpace0 = float4(normalInput.normalWS, positionWS.x);
                o.tSpace1 = float4(normalInput.tangentWS, positionWS.y);
                o.tSpace2 = float4(normalInput.bitangentWS, positionWS.z);

                #if defined(LIGHTMAP_ON)
					OUTPUT_LIGHTMAP_UV(v.texcoord1, unity_LightmapST, o.lightmapUVOrVertexSH.xy);
                #endif

                #if defined(DYNAMICLIGHTMAP_ON)
					o.dynamicLightmapUV.xy = v.texcoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif

                #if !defined(LIGHTMAP_ON)
                OUTPUT_SH(normalInput.normalWS.xyz, o.lightmapUVOrVertexSH.xyz);
                #endif

                #if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					o.lightmapUVOrVertexSH.zw = v.texcoord.xy;
					o.lightmapUVOrVertexSH.xy = v.texcoord.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                half3 vertexLight = VertexLighting(positionWS, normalInput.normalWS);

                o.fogFactorAndVertexLight = half4(0, vertexLight);

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
                #endif

                o.clipPos = positionCS;
                o.clipPosV = positionCS;
                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }


            FragmentOutput frag(VertexOutput IN
                #ifdef ASE_DEPTH_WRITE_ON
								,out float outputDepth : ASE_SV_DEPTH
                #endif
            )
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                #ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.clipPos );
                #endif

                #if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float2 sampleCoords = (IN.lightmapUVOrVertexSH.zw / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
					float3 WorldNormal = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
					float3 WorldTangent = -cross(GetObjectToWorldMatrix()._13_23_33, WorldNormal);
					float3 WorldBiTangent = cross(WorldNormal, -WorldTangent);
                #else
                float3 WorldNormal = normalize(IN.tSpace0.xyz);
                float3 WorldTangent = IN.tSpace1.xyz;
                float3 WorldBiTangent = IN.tSpace2.xyz;
                #endif

                float3 WorldPosition = float3(IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w);
                float3 WorldViewDirection = _WorldSpaceCameraPos.xyz - WorldPosition;
                float4 ShadowCoords = float4(0, 0, 0, 0);

                float4 ClipPos = IN.clipPosV;
                float4 ScreenPos = ComputeScreenPos(IN.clipPosV);

                float2 NormalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.clipPos);

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					ShadowCoords = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
                #else
                ShadowCoords = float4(0, 0, 0, 0);
                #endif

                WorldViewDirection = SafeNormalize(WorldViewDirection);

                float2 uv_BaseMap = IN.ase_texcoord8.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 tanToWorld0 = float3(WorldTangent.x, WorldBiTangent.x, WorldNormal.x);
                float3 tanToWorld1 = float3(WorldTangent.y, WorldBiTangent.y, WorldNormal.y);
                float3 tanToWorld2 = float3(WorldTangent.z, WorldBiTangent.z, WorldNormal.z);
                float3 ase_tanViewDir = tanToWorld0 * WorldViewDirection.x + tanToWorld1 * WorldViewDirection.y +
                    tanToWorld2 * WorldViewDirection.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
                float2 staticSwitch297 = (uv_BaseMap + paralaxOffset282);
                #else
				float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);

                float3 unpack21 = UnpackNormalScale(tex2D(_BumpMap, staticSwitch297), _BumpScale);
                unpack21.z = lerp(1, unpack21.z, saturate(_BumpScale));
                #ifdef _NORMALMAP
                float3 staticSwitch223 = unpack21;
                #else
				float3 staticSwitch223 = float3(0,0,1);
                #endif
                float3 Normal77 = staticSwitch223;

                #ifdef _EMISSION
				float3 staticSwitch182 = ( (_EmissionColor).rgb * (tex2D( _EmissionMap, staticSwitch297 )).rgb );
                #else
                float3 staticSwitch182 = float3(0, 0, 0);
                #endif
                float3 Emissive104 = staticSwitch182;
                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord8.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord9.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord9.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float lerpResult9_g6 = lerp(0.0, (1.0 + temp_output_2_0_g6), temp_output_1_0_g6);
                #ifdef _ALPHATEST_ON
				float4 staticSwitch388 = ( ( ( temp_output_7_0_g6 - step( lerpResult9_g6 , temp_output_3_0_g6 ) ) * _EdgeColor ) * _EdgeColorIntensity );
                #else
                float4 staticSwitch388 = float4(Emissive104, 0.0);
                #endif

                sampler2D tex244 = _MetallicGlossMap;
                SamplerState ss244 = sampler_MetallicGlossMap;
                half2 uv244 = staticSwitch297;
                float BaseAlpha175 = tex2DNode10.a;
                half albedoAlpha244 = BaseAlpha175;
                half metallic244 = _Metallic;
                half smoothness244 = _Smoothness;
                half4 localSampleMetallicSpecGloss244 = SampleMetallicSpecGloss(
                    tex244, ss244, uv244, albedoAlpha244, metallic244, smoothness244);
                float Metallic79 = ((localSampleMetallicSpecGloss244).xyz).x;

                float Smoothness116 = (localSampleMetallicSpecGloss244).w;

                float3 temp_cast_2 = (tex2D(_OcclusionMap, staticSwitch297).g).xxx;
                float temp_output_2_0_g2 = _OcclusionStrength;
                float temp_output_3_0_g2 = (1.0 - temp_output_2_0_g2);
                float3 appendResult7_g2 = (float3(temp_output_3_0_g2, temp_output_3_0_g2, temp_output_3_0_g2));
                float AO81 = (((temp_cast_2 * temp_output_2_0_g2) + appendResult7_g2)).x;

                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                float3 BaseColor = (BaseMap89).rgb;
                float3 Normal = Normal77;
                float3 Emission = staticSwitch388.rgb;
                float3 Specular = 0.5;
                float Metallic = Metallic79;
                float Smoothness = Smoothness116;
                float Occlusion = AO81;
                float Alpha = temp_output_206_0;
                float AlphaClipThreshold = staticSwitch333;
                float AlphaClipThresholdShadow = 0.5;
                float3 BakedGI = 0;
                float3 RefractionColor = 1;
                float RefractionIndex = 1;
                float3 Transmission = 1;
                float3 Translucency = 1;

                #ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = IN.clipPos.z;
                #endif

                #ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
                #endif

                InputData inputData = (InputData)0;
                inputData.positionWS = WorldPosition;
                inputData.positionCS = IN.clipPos;
                inputData.shadowCoord = ShadowCoords;

                #ifdef _NORMALMAP
                #if _NORMAL_DROPOFF_TS
                inputData.normalWS =
                    TransformTangentToWorld(Normal, half3x3(WorldTangent, WorldBiTangent, WorldNormal));
                #elif _NORMAL_DROPOFF_OS
						inputData.normalWS = TransformObjectToWorldNormal(Normal);
                #elif _NORMAL_DROPOFF_WS
						inputData.normalWS = Normal;
                #endif
                #else
					inputData.normalWS = WorldNormal;
                #endif

                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                inputData.viewDirectionWS = SafeNormalize(WorldViewDirection);

                inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;

                #if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float3 SH = SampleSH(inputData.normalWS.xyz);
                #else
                float3 SH = IN.lightmapUVOrVertexSH.xyz;
                #endif

                #ifdef ASE_BAKEDGI
					inputData.bakedGI = BakedGI;
                #else
                #if defined(DYNAMICLIGHTMAP_ON)
						inputData.bakedGI = SAMPLE_GI( IN.lightmapUVOrVertexSH.xy, IN.dynamicLightmapUV.xy, SH, inputData.normalWS);
                #else
                inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy, SH, inputData.normalWS);
                #endif
                #endif

                inputData.normalizedScreenSpaceUV = NormalizedScreenSpaceUV;
                inputData.shadowMask = SAMPLE_SHADOWMASK(IN.lightmapUVOrVertexSH.xy);

                #if defined(DEBUG_DISPLAY)
                #if defined(DYNAMICLIGHTMAP_ON)
						inputData.dynamicLightmapUV = IN.dynamicLightmapUV.xy;
                #endif
                #if defined(LIGHTMAP_ON)
						inputData.staticLightmapUV = IN.lightmapUVOrVertexSH.xy;
                #else
						inputData.vertexSH = SH;
                #endif
                #endif

                #ifdef _DBUFFER
					ApplyDecal(IN.clipPos,
						BaseColor,
						Specular,
						inputData.normalWS,
						Metallic,
						Occlusion,
						Smoothness);
                #endif

                BRDFData brdfData;
                InitializeBRDFData
                    (BaseColor, Metallic, Specular, Smoothness, Alpha, brdfData);

                Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
                half4 color;
                MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
                color.rgb = GlobalIllumination(brdfData, inputData.bakedGI, Occlusion, inputData.positionWS,
                                               inputData.normalWS, inputData.viewDirectionWS);
                color.a = Alpha;

                #ifdef ASE_FINAL_COLOR_ALPHA_MULTIPLY
					color.rgb *= color.a;
                #endif

                #ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
                #endif

                return BRDFDataToGbuffer(brdfData, inputData, Smoothness, Emission + color.rgb, Occlusion);
            }
            ENDHLSL
        }


        Pass
        {

            Name "SceneSelectionPass"
            Tags
            {
                "LightMode"="SceneSelectionPass"
            }

            Cull Off

            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #define ASE_FOG 1
            #define ASE_SRP_VERSION 140008


            #pragma vertex vert
            #pragma fragment frag

            #define SCENESELECTIONPASS 1

            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define SHADERPASS SHADERPASS_DEPTHONLY

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float4 clipPos : SV_POSITION;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_texcoord1 : TEXCOORD1;
                float4 ase_texcoord2 : TEXCOORD2;
                float4 ase_texcoord3 : TEXCOORD3;
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
				float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
            int _ObjectId;
            int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/SelectionPickingPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }


            struct SurfaceDescription
            {
                float Alpha;
                float AlphaClipThreshold;
            };

            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o;
                ZERO_INITIALIZE(VertexOutput, o);

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                o.ase_texcoord1.xyz = ase_worldTangent;
                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                o.ase_texcoord2.xyz = ase_worldNormal;
                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord3.xyz = ase_worldBitangent;
                float3 ase_worldPos = TransformObjectToWorld((v.vertex).xyz);
                o.ase_texcoord4.xyz = ase_worldPos;

                o.ase_texcoord.xy = v.ase_texcoord.xy;
                o.ase_texcoord5 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord.zw = 0;
                o.ase_texcoord1.w = 0;
                o.ase_texcoord2.w = 0;
                o.ase_texcoord3.w = 0;
                o.ase_texcoord4.w = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;

                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);

                o.clipPos = TransformWorldToHClip(positionWS);

                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }

            half4 frag(VertexOutput IN) : SV_TARGET
            {
                SurfaceDescription surfaceDescription = (SurfaceDescription)0;

                float2 uv_BaseMap = IN.ase_texcoord.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldTangent = IN.ase_texcoord1.xyz;
                float3 ase_worldNormal = IN.ase_texcoord2.xyz;
                float3 ase_worldBitangent = IN.ase_texcoord3.xyz;
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 ase_worldPos = IN.ase_texcoord4.xyz;
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - ase_worldPos);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
				float2 staticSwitch297 = ( uv_BaseMap + paralaxOffset282 );
                #else
                float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);
                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord5.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord5.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                surfaceDescription.Alpha = temp_output_206_0;
                surfaceDescription.AlphaClipThreshold = staticSwitch333;

                #if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
                #if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
                #endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
                #endif

                half4 outColor = 0;

                #ifdef SCENESELECTIONPASS
                outColor = half4(_ObjectId, _PassValue, 1.0, 1.0);
                #elif defined(SCENEPICKINGPASS)
					outColor = _SelectionID;
                #endif

                return outColor;
            }
            ENDHLSL
        }


        Pass
        {

            Name "ScenePickingPass"
            Tags
            {
                "LightMode"="Picking"
            }

            HLSLPROGRAM
            #define _NORMAL_DROPOFF_TS 1
            #define ASE_FOG 1
            #define ASE_SRP_VERSION 140008


            #pragma vertex vert
            #pragma fragment frag

            #define SCENEPICKINGPASS 1

            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define SHADERPASS SHADERPASS_DEPTHONLY

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #define ASE_NEEDS_VERT_NORMAL
            #define ASE_NEEDS_FRAG_POSITION
            #pragma shader_feature_local BOOLEAN_USE_WROLDSPACE_ON
            #pragma shader_feature_local BOOLEAN_WORLDORIGIN_ON
            #pragma shader_feature_local BOOLEAN_DIRECTION_FROM_EULERANGLE_ON


            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float4 clipPos : SV_POSITION;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_texcoord1 : TEXCOORD1;
                float4 ase_texcoord2 : TEXCOORD2;
                float4 ase_texcoord3 : TEXCOORD3;
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float4 _EmissionColor;
                float3 _DissolveOffset;
                float3 _DissolveDirection;
                float2 _NoiseUVSpeed;
                float _Metallic;
                float _EdgeColorIntensity;
                float _BumpScale;
                float _SmoothnessTextureChannel;
                float _Smoothness;
                float _NoiseScale;
                float _EdgeWidth;
                float _Parallax;
                float _AlphaClip;
                float _DirectionEdgeWidthScale;
                float _OcclusionStrength;
                #ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
                #endif
                #ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
                #endif
            CBUFFER_END

            // Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
            float4 _SelectionID;
            #endif

            // Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
            #endif

            sampler2D _BaseMap;
            sampler2D _ParallaxMap;


            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/SelectionPickingPass.hlsl"

            //#ifdef HAVE_VFX_MODIFICATION
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
            //#endif

            inline float2 ParallaxOffset(half h, half height, half3 viewDir)
            {
                h = h * height - height / 2.0;
                float3 v = normalize(viewDir);
                v.z += 0.42;
                return h * (v.xy / v.z);
            }

            inline float noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float noise_interpolate(float a, float b, float t) { return (1.0 - t) * a + (t * b); }

            inline float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = noise_randomValue(c0);
                float r1 = noise_randomValue(c1);
                float r2 = noise_randomValue(c2);
                float r3 = noise_randomValue(c3);
                float bottomOfGrid = noise_interpolate(r0, r1, f.x);
                float topOfGrid = noise_interpolate(r2, r3, f.x);
                float t = noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV)
            {
                float t = 0.0;
                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += valueNoise(UV / freq) * amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += valueNoise(UV / freq) * amp;
                return t;
            }

            float3 ObjectPosition19_g7()
            {
                return GetAbsolutePositionWS(UNITY_MATRIX_M._m03_m13_m23);
            }


            struct SurfaceDescription
            {
                float Alpha;
                float AlphaClipThreshold;
            };

            VertexOutput VertexFunction(VertexInput v)
            {
                VertexOutput o;
                ZERO_INITIALIZE(VertexOutput, o);

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
                o.ase_texcoord1.xyz = ase_worldTangent;
                float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
                o.ase_texcoord2.xyz = ase_worldNormal;
                float ase_vertexTangentSign = v.ase_tangent.w * (unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0);
                float3 ase_worldBitangent = cross(ase_worldNormal, ase_worldTangent) * ase_vertexTangentSign;
                o.ase_texcoord3.xyz = ase_worldBitangent;
                float3 ase_worldPos = TransformObjectToWorld((v.vertex).xyz);
                o.ase_texcoord4.xyz = ase_worldPos;

                o.ase_texcoord.xy = v.ase_texcoord.xy;
                o.ase_texcoord5 = v.vertex;

                //setting value to unused interpolator channels and avoid initialization warnings
                o.ase_texcoord.zw = 0;
                o.ase_texcoord1.w = 0;
                o.ase_texcoord2.w = 0;
                o.ase_texcoord3.w = 0;
                o.ase_texcoord4.w = 0;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif

                float3 vertexValue = defaultVertexValue;

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = v.ase_normal;

                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.clipPos = TransformWorldToHClip(positionWS);

                return o;
            }

            VertexOutput vert(VertexInput v)
            {
                return VertexFunction(v);
            }

            half4 frag(VertexOutput IN) : SV_TARGET
            {
                SurfaceDescription surfaceDescription = (SurfaceDescription)0;

                float2 uv_BaseMap = IN.ase_texcoord.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float3 ase_worldTangent = IN.ase_texcoord1.xyz;
                float3 ase_worldNormal = IN.ase_texcoord2.xyz;
                float3 ase_worldBitangent = IN.ase_texcoord3.xyz;
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 ase_worldPos = IN.ase_texcoord4.xyz;
                float3 ase_worldViewDir = (_WorldSpaceCameraPos.xyz - ase_worldPos);
                ase_worldViewDir = normalize(ase_worldViewDir);
                float3 ase_tanViewDir = tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y +
                    tanToWorld2 * ase_worldViewDir.z;
                ase_tanViewDir = normalize(ase_tanViewDir);
                float2 paralaxOffset282 = ParallaxOffset(tex2D(_ParallaxMap, uv_BaseMap).g, _Parallax, ase_tanViewDir);
                #ifdef _PARALLAXMAP
				float2 staticSwitch297 = ( uv_BaseMap + paralaxOffset282 );
                #else
                float2 staticSwitch297 = uv_BaseMap;
                #endif
                float4 tex2DNode10 = tex2D(_BaseMap, staticSwitch297);
                float4 BaseMap89 = (tex2DNode10 * _BaseColor);
                float temp_output_206_0 = (BaseMap89).a;

                float temp_output_2_0_g6 = _EdgeWidth;
                float temp_output_1_0_g6 = 0.5;
                float lerpResult5_g6 = lerp((0.0 - temp_output_2_0_g6), 1.0, temp_output_1_0_g6);
                float2 texCoord384 = IN.ase_texcoord.xy * float2(1, 1) + float2(0, 0);
                float simpleNoise372 = SimpleNoise(
                    (texCoord384 + (_NoiseUVSpeed * (_TimeParameters.x * 0.005))) * _NoiseScale);
                float3 temp_output_2_0_g7 = _DissolveOffset;
                float3 objToWorld12_g7 = mul(GetObjectToWorldMatrix(), float4(IN.ase_texcoord5.xyz, 1)).xyz;
                float3 localObjectPosition19_g7 = ObjectPosition19_g7();
                #ifdef BOOLEAN_WORLDORIGIN_ON
                float3 staticSwitch15_g7 = temp_output_2_0_g7;
                #else
				float3 staticSwitch15_g7 = ( localObjectPosition19_g7 + temp_output_2_0_g7 );
                #endif
                #ifdef BOOLEAN_USE_WROLDSPACE_ON
                float3 staticSwitch7_g7 = (objToWorld12_g7 - staticSwitch15_g7);
                #else
				float3 staticSwitch7_g7 = ( IN.ase_texcoord5.xyz - temp_output_2_0_g7 );
                #endif
                float3 normalizeResult383 = normalize((_DissolveDirection + float3(0, 0.001, 0)));
                float3 break5_g8 = radians(_DissolveDirection);
                float temp_output_6_0_g8 = sin(break5_g8.x);
                float temp_output_13_0_g8 = sin(break5_g8.y);
                float temp_output_19_0_g8 = cos(break5_g8.z);
                float temp_output_11_0_g8 = cos(break5_g8.x);
                float temp_output_21_0_g8 = sin(break5_g8.z);
                float3 appendResult10_g8 = (float3(
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_19_0_g8) - (temp_output_11_0_g8 *
                        temp_output_21_0_g8)),
                    (((temp_output_6_0_g8 * temp_output_13_0_g8) * temp_output_21_0_g8) + (temp_output_11_0_g8 *
                        temp_output_19_0_g8)), (temp_output_6_0_g8 * cos(break5_g8.y))));
                #ifdef BOOLEAN_DIRECTION_FROM_EULERANGLE_ON
                float3 staticSwitch378 = appendResult10_g8;
                #else
				float3 staticSwitch378 = normalizeResult383;
                #endif
                float dotResult10_g7 = dot(staticSwitch7_g7, staticSwitch378);
                float temp_output_3_0_g6 = (simpleNoise372 + (dotResult10_g7 * _DirectionEdgeWidthScale));
                float temp_output_7_0_g6 = step(lerpResult5_g6, temp_output_3_0_g6);
                float temp_output_10_0_g5 = (1.0 - temp_output_7_0_g6);
                #ifdef _ALPHATEST_ON
				float staticSwitch333 = ( temp_output_10_0_g5 + 0.0001 );
                #else
                float staticSwitch333 = 0.0;
                #endif


                surfaceDescription.Alpha = temp_output_206_0;
                surfaceDescription.AlphaClipThreshold = staticSwitch333;

                #if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
                #if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
                #endif
						clip(surfaceDescription.Alpha - alphaClipThreshold);
                #endif

                half4 outColor = 0;

                #ifdef SCENESELECTIONPASS
					outColor = half4(_ObjectId, _PassValue, 1.0, 1.0);
                #elif defined(SCENEPICKINGPASS)
                outColor = _SelectionID;
                #endif

                return outColor;
            }
            ENDHLSL
        }

    }

    CustomEditor "NKStudio.ASEMaterialDissolveOutlineGUI"
    FallBack "Hidden/Shader Graph/FallbackError"

    Fallback Off
}