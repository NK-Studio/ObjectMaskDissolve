Shader "Universal Render Pipeline/RealToon"
{
    Properties
    {

        [Enum(UnityEngine.Rendering.CullMode)] _Culling("Culling", int) = 2

        [Toggle(N_F_TRANS_ON)] _TRANSMODE("Transparent Mode", Float) = 0.0

        _MainTex ("Texture", 2D) = "white" {}
        [ToggleOff] _TexturePatternStyle ("Texture Pattern Style", Float ) = 0.0
        [HDR] _MainColor ("Main Color", Color) = (1.0,1.0,1.0,1.0)
        _MaiColPo("Main Color Power", Float) = 0.8

        [ToggleOff] _MVCOL ("Mix Vertex Color", Float ) = 0.0

        [ToggleOff] _MCIALO ("Main Color In Ambient Light Only", Float ) = 0.0

        [HDR] _HighlightColor ("Highlight Color", Color) = (1.0,1.0,1.0,1.0)
        _HighlightColorPower ("Highlight Color Power", Float ) = 1.0

        _MCapIntensity ("Intensity", Range(0, 1)) = 1.0
        _MCap ("MatCap", 2D) = "white" {}
        [ToggleOff] _SPECMODE ("Specular Mode", Float ) = 0.0
        _SPECIN ("Specular Power", Float ) = 1
        _MCapMask ("Mask MatCap", 2D) = "white" {}

        _Cutout ("Cutout", Range(0, 1)) = 0.0
        [ToggleOff] _AlphaBaseCutout ("Alpha Base Cutout", Float ) = 1.0
        [ToggleOff] _UseSecondaryCutout ("Use Secondary Cutout Only", Float ) = 0.0
        _SecondaryCutout ("Secondary Cutout", 2D) = "white" {}

        [Toggle(N_F_COEDGL_ON)] _N_F_COEDGL("Enable Glow Edge", Float) = 0.0
        [HDR] _Glow_Color("Glow Color", Color) = (1.0,1.0,1.0,1.0)
        _Glow_Edge_Width("Glow Edge Width", Float) = 1.0

        [Toggle(N_F_SIMTRANS_ON)] _SimTrans("Simple Transparency Mode", Float) = 0.0
        _Opacity("Opacity", Range(0, 1)) = 1.0
        _TransparentThreshold("Transparent Threshold", Float) = 0.0

        [Enum(UnityEngine.Rendering.BlendMode)] _BleModSour("Blend - Source", int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _BleModDest("Blend - Destination", int) = 0

        _MaskTransparency("Mask Transparency", 2D) = "black" {}

        [Toggle(N_F_TRANSAFFSHA_ON)] _TransAffSha("Affect Shadow", Float) = 1.0

        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalMapIntensity ("Normal Map Intensity", Float ) = 1.0

        _Saturation ("Saturation", Range(0, 2)) = 1.0

        _OutlineWidth ("Width", Float ) = 0.5
        _OutlineWidthControl ("Width Control", 2D) = "white" {}

        [Enum(Normal,0,Origin,1)] _OutlineExtrudeMethod("Outline Extrude Method", int) = 0

        _OutlineOffset ("Outline Offset", Vector) = (0,0,0)
        _OutlineZPostionInCamera ("Outline Z Position In Camera", Float) = 0.0

        [Enum(Off,1,On,0)] _DoubleSidedOutline("Double Sided Outline", int) = 1

        [HDR] _OutlineColor ("Color", Color) = (0.0,0.0,0.0,1.0)

        [ToggleOff] _MixMainTexToOutline ("Mix Main Texture To Outline", Float ) = 0.0

        _NoisyOutlineIntensity ("Noisy Outline Intensity", Range(0, 1)) = 0.0
        [Toggle(N_F_DNO_ON)] _DynamicNoisyOutline ("Dynamic Noisy Outline", Float ) = 0.0
        [ToggleOff] _LightAffectOutlineColor ("Light Affect Outline Color", Float ) = 0.0

        [ToggleOff] _OutlineWidthAffectedByViewDistance ("Outline Width Affected By View Distance", Float ) = 0.0
        _FarDistanceMaxWidth ("Far Distance Max Width", Float ) = 10.0

        [ToggleOff] _VertexColorBlueAffectOutlineWitdh ("Vertex Color Blue Affect Outline Witdh", Float ) = 0.0

        _DepthThreshold("Depth Threshold", Float) = 900.0

        [Toggle(N_F_O_MOTTSO_ON)] _N_F_MSSOLTFO("Mix Outline To The Shader Output", Float) = 0.0

        _SelfLitIntensity ("Intensity", Range(0, 1)) = 0.0
        [HDR] _SelfLitColor ("Color", Color) = (1.0,1.0,1.0,1.0)
        _SelfLitPower ("Power", Float ) = 2.0
        _TEXMCOLINT ("Texture and Main Color Intensity", Float ) = 1.0
        [ToggleOff] _SelfLitHighContrast ("High Contrast", Float ) = 1.0
        _MaskSelfLit ("Mask Self Lit", 2D) = "white" {}

        _GlossIntensity ("Gloss Intensity", Range(0, 1)) = 1.0
        _Glossiness ("Glossiness", Range(0, 1)) = 0.6
        _GlossSoftness ("Softness", Range(0, 1)) = 0.0
        [HDR] _GlossColor ("Color", Color) = (1.0,1.0,1.0,1.0)
        _GlossColorPower ("Color Power", Float ) = 10.0
        _MaskGloss ("Mask Gloss", 2D) = "white" {}

        _GlossTexture ("Gloss Texture", 2D) = "black" {}
        _GlossTextureSoftness ("Softness", Float ) = 0.0
        [ToggleOff] _PSGLOTEX ("Pattern Style", Float ) = 0.0
        _GlossTextureRotate ("Rotate", Float ) = 0.0
        [ToggleOff] _GlossTextureFollowObjectRotation ("Follow Object Rotation", Float ) = 0.0
        _GlossTextureFollowLight ("Follow Light", Range(0, 1)) = 0.0

        [HDR] _OverallShadowColor ("Overall Shadow Color", Color) = (0.0,0.0,0.0,1.0)
        _OverallShadowColorPower ("Overall Shadow Color Power", Float ) = 1.0

        [ToggleOff] _SelfShadowShadowTAtViewDirection ("Self Shadow & ShadowT At View Direction", Float ) = 0.0

        _ReduSha ("Reduce Shadow", Float ) = 0.5

        _ShadowHardness ("Shadow Hardness", Range(0, 1)) = 0.0

        _SelfShadowRealtimeShadowIntensity ("Self Shadow & Realtime Shadow Intensity", Range(0, 1)) = 1.0
        _SelfShadowThreshold ("Threshold", Range(0, 1)) = 0.930
        [ToggleOff] _VertexColorGreenControlSelfShadowThreshold ("Vertex Color Green Control Self Shadow Threshold", Float ) = 0.0
        _SelfShadowHardness ("Hardness", Range(0, 1)) = 1.0
        [HDR] _SelfShadowRealTimeShadowColor ("Self Shadow & Real Time Shadow Color", Color) = (1.0,1.0,1.0,1.0)
        _SelfShadowRealTimeShadowColorPower ("Self Shadow & Real Time Shadow Color Power", Float ) = 1.0
        [ToggleOff] _LigIgnoYNorDir ("Light Ignore Y Normal Direction", Float) = 0
        [ToggleOff] _SelfShadowAffectedByLightShadowStrength ("Self Shadow Affected By Light Shadow Strength", Float ) = 0.0

        _SmoothObjectNormal ("Smooth Object Normal", Range(0, 1)) = 0.0
        [ToggleOff] _VertexColorRedControlSmoothObjectNormal ("Vertex Color Red Control Smooth Object Normal", Float ) = 0.0
        _XYZPosition ("XYZ Position", Vector) = (0.0,0.0,0.0,0.0)
        [ToggleOff] _ShowNormal ("Show Normal", Float ) = 0.0

        _ShadowColorTexture ("Shadow Color Texture", 2D) = "white" {}
        _ShadowColorTexturePower ("Power", Float ) = 0.0

        _ShadowTIntensity ("ShadowT Intensity", Range(0, 1)) = 1.0
        _ShadowT ("ShadowT", 2D) = "white" {}
        _ShadowTLightThreshold ("Light Threshold", Float ) = 50.0
        _ShadowTShadowThreshold ("Shadow Threshold", Float ) = 0.0
        _ShadowTHardness ("Hardness", Range(0, 1)) = 1.0
        [HDR] _ShadowTColor ("Color", Color) = (1.0,1.0,1.0,1.0)
        _ShadowTColorPower ("Color Power", Float ) = 1.0

        [ToggleOff] _STIL ("Ignore Light", Float ) = 0.0

        [Toggle(N_F_STIS_ON)] _N_F_STIS ("Show In Shadow", Float ) = 0.0

        [Toggle(N_F_STIAL_ON )] _N_F_STIAL ("Show In Ambient Light", Float ) = 0.0
        _ShowInAmbientLightShadowIntensity ("Show In Ambient Light & Shadow Intensity", Range(0, 1)) = 1.0
        _ShowInAmbientLightShadowThreshold ("Show In Ambient Light & Shadow Threshold", Float ) = 0.4

        [ToggleOff] _LightFalloffAffectShadowT ("Light Falloff Affect ShadowT", Float ) = 0.0

        _PTexture ("PTexture", 2D) = "white" {}
        _PTCol("Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _PTexturePower ("Power", Float ) = 1.0

        [Toggle(N_F_RELGI_ON)] _RELG ("Receive Environmental Lighting and GI", Float ) = 1.0
        _EnvironmentalLightingIntensity ("Environmental Lighting Intensity", Float ) = 1.0

        [ToggleOff] _GIFlatShade ("GI Flat Shade", Float ) = 0.0
        _GIShadeThreshold ("GI Shade Threshold", Range(0, 1)) = 0.0

        [ToggleOff] _LightAffectShadow ("Light Affect Shadow", Float ) = 0.0
        _LightIntensity ("Light Intensity", Float ) = 1.0

        [Toggle(N_F_USETLB_ON)] _UseTLB ("Use Traditional Light Blend", Float ) = 0.0
        [Toggle(N_F_EAL_ON)] _N_F_EAL ("Enable Additional Lights", Float ) = 1.0

        _DirectionalLightIntensity ("Directional Light Intensity", Float ) = 0.0
        _PointSpotlightIntensity ("Point and Spot Light Intensity", Float ) = 0.0
        _LightFalloffSoftness ("Light Falloff Softness", Range(0, 1)) = 1.0

        _CustomLightDirectionIntensity ("Intensity", Range(0, 1)) = 0.0
        [ToggleOff] _CustomLightDirectionFollowObjectRotation ("Follow Object Rotation", Float ) = 0.0
        _CustomLightDirection ("Custom Light Direction", Vector) = (0.0,0.0,10.0,0.0)

        _ReflectionIntensity ("Intensity", Range(0, 1)) = 0.0
        _ReflectionRoughtness ("Roughness", Float ) = 0.0
        _RefMetallic ("Metallic", Range(0, 1) ) = 0.0

        _MaskReflection ("Mask Reflection", 2D) = "white" {}

        _FReflection ("FReflection", 2D) = "black" {}

        _RimLigInt("Rim Light Intensity", Range(0, 1)) = 1.0
        _RimLightUnfill ("Unfill", Float ) = 1.5
        [HDR] _RimLightColor ("Color", Color) = (1.0,1.0,1.0,1.0)
        _RimLightColorPower ("Color Power", Float ) = 10.0
        _RimLightSoftness ("Softness", Range(0, 1)) = 1.0
        [ToggleOff] _RimLightInLight ("Rim Light In Light", Float ) = 1.0
        [ToggleOff] _LightAffectRimLightColor ("Light Affect Rim Light Color", Float ) = 0.0

        _MinFadDistance("Min Distance", Float) = 0.0
        _MaxFadDistance("Max Distance", Float) = 2.0

        _RefVal ("ID", int ) = 0
        [Enum(Blank,8,A,0,B,2)] _Oper("Set 1", int) = 0
        [Enum(Blank,8,None,4,A,6,B,7)] _Compa("Set 2", int) = 4

        [Toggle(N_F_MC_ON)] _N_F_MC ("MatCap", Float ) = 0.0
        [Toggle(N_F_NM_ON)] _N_F_NM ("Normal Map", Float ) = 0.0
        [Toggle(N_F_CO_ON)] _N_F_CO ("Cutout", Float ) = 0.0
        [Toggle(N_F_O_ON)] _N_F_O ("Outline", Float ) = 1.0
        [Toggle(N_F_CA_ON)] _N_F_CA ("Color Adjustment", Float ) = 0.0
        [Toggle(N_F_SL_ON)] _N_F_SL ("Self Lit", Float ) = 0.0
        [Toggle(N_F_GLO_ON)] _N_F_GLO ("Gloss", Float ) = 0.0
        [Toggle(N_F_GLOT_ON)] _N_F_GLOT ("Gloss Texture", Float ) = 0.0
        [Toggle(N_F_SS_ON)] _N_F_SS ("Self Shadow", Float ) = 1.0
        [Toggle(N_F_SON_ON)] _N_F_SON ("Smooth Object Normal", Float ) = 0.0
        [Toggle(N_F_SCT_ON)] _N_F_SCT ("Shadow Color Texture", Float ) = 0.0
        [Toggle(N_F_ST_ON)] _N_F_ST ("ShadowT", Float ) = 0.0
        [Toggle(N_F_PT_ON)] _N_F_PT ("PTexture", Float ) = 0.0
        [Toggle(N_F_CLD_ON)] _N_F_CLD ("Custom Light Direction", Float ) = 0.0
        [Toggle(N_F_R_ON)] _N_F_R ("Relfection", Float ) = 0.0
        [Toggle(N_F_FR_ON)] _N_F_FR ("FRelfection", Float ) = 0.0
        [Toggle(N_F_RL_ON)] _N_F_RL ("Rim Light", Float ) = 0.0
        [Toggle(N_F_NFD_ON)] _N_F_NFD ("Near Fade Dithering", Float) = 0.0

        [Toggle(N_F_HDLS_ON)] _N_F_HDLS ("Hide Directional Light Shadow", Float ) = 0.0
        [Toggle(N_F_HPSS_ON)] _N_F_HPSS ("Hide Point & Spot Light Shadow", Float ) = 0.0

        [Toggle(N_F_DCS_ON)] _N_F_DCS ("Disable Cast Shadow", Float ) = 0.0
        [Toggle(N_F_NLASOBF_ON)] _N_F_NLASOBF ("No Light and Shadow On BackFace", Float ) = 0.0

        [Toggle(N_F_ESSAO_ON)] _N_F_ESSAO("Enable Screen Space Ambient Occlusion", Float) = 0.0
        [HDR] _SSAOColor("Ambient Occlusion Color", Color) = (0.0, 0.0, 0.0, 0.0)

        [Toggle(N_F_RDC_ON)] _N_F_RDC("Receive Decal", Float) = 1.0
        [Toggle(N_F_OFLMB_ON)] _N_F_OFLMB("Optimize for [Light Mode: Baked]", Float) = 0.0

        [Toggle(N_F_DDMD_ON)] _N_F_DDMD("Disable DOTS Mesh Deformation", Float) = 0.0

        [Enum(On, 1, Off, 0)] _ZWrite("ZWrite", int) = 1

        //Others
        [HideInInspector]_SkinMatrixIndex("Skin Matrix Index Offset", Float) = 0
        [HideInInspector]_ComputeMeshIndex("Compute Mesh Buffer Index Offset", Float) = 0


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
            #include "Assets/RealToon/RealToon Shaders/RealToon Core/URP/RT_URP_Core.hlsl"

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


            Varyings LitPassVertex(Attributes input)
            {
                Varyings output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.uv = input.uv;
                output.vertexColor = input.vertexColor;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                half4 _OutlineWidthControl_var = SAMPLE_TEXTURE2D_LOD(_OutlineWidthControl, sampler_OutlineWidthControl,
                                                                      TRANSFORM_TEX(output.uv, _OutlineWidthControl),
                                                                      0.0);

                float2 _1283_skew = output.uv + 0.2127 + output.uv.x * 0.3713 * output.uv.y;
                float2 _1283_rnd = 4.789 * sin(489.123 * _1283_skew);
                half _1283 = frac(_1283_rnd.x * _1283_rnd.y * (1 + _1283_skew.x));

                float3 _OEM;

                // Normal과 Origin 중 선택
                if (!_OutlineExtrudeMethod)
                    _OEM = input.normalOS;
                else
                    _OEM = normalize(input.positionOS.xyz);

                half RTD_OL = _OutlineWidth * 0.01 * _OutlineWidthControl_var.r * lerp(
                    1.0, _1283, _NoisyOutlineIntensity);

                output.positionCS = mul(GetWorldToHClipMatrix(),
       mul(GetObjectToWorldMatrix(),
                                           float4(input.positionOS.xyz + _OutlineOffset.xyz * 0.01 + _OEM * RTD_OL,
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

                Light mainLight = GetMainLight();
                half3 color = 1.0;

                float4 objPos = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0));
                float2 sceneUVs = input.projPos.xy / input.projPos.w;

                half RTD_OB_VP_CAL = distance(objPos.rgb, _WorldSpaceCameraPos);
                half2 RTD_VD_Cal = float2((sceneUVs.x * 2.0 - 1.0) * (_ScreenParams.r / _ScreenParams.g),
    sceneUVs.y * 2.0 - 1.0).rg * RTD_OB_VP_CAL;

                half2 RTD_TC_TP_OO = input.uv;
                half4 _MainTex_var = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(RTD_TC_TP_OO, _MainTex));

                //RT_TRANS_CO
                half RTD_TRAN_OPA_Sli;
                half RTD_CO;
                half3 GLO_OUT;
                RT_TRANS_CO(input.uv, _MainTex_var, RTD_TRAN_OPA_Sli, RTD_CO, GLO_OUT);

                //-------------
                RTD_TRAN_OPA_Sli = 1.0;
                GLO_OUT = (half3)0.0;

                #if N_F_TRANS_ON

                #if N_F_CO_ON

			half4 _SecondaryCutout_var = SAMPLE_TEXTURE2D(_SecondaryCutout, sampler_SecondaryCutout ,TRANSFORM_TEX(uv,_SecondaryCutout));

			half RT_USSECCUT_OO;
			if (!_UseSecondaryCutout)
			{
				RT_USSECCUT_OO = _MainTex_var.r * _SecondaryCutout_var.r;
			}
			else
			{
				RT_USSECCUT_OO = _SecondaryCutout_var.r;
			}

			half RT_USSECCUT_OO_2;
			if (!_UseSecondaryCutout)
			{
				RT_USSECCUT_OO_2 = _MainTex_var.a * _SecondaryCutout_var.r;
			}
			else
			{
				RT_USSECCUT_OO_2 = _SecondaryCutout_var.a;
			}

			half RTD_CO_ON = (half)lerp((RT_USSECCUT_OO + lerp(0.5, (-1.0), _Cutout)), saturate(((1.0 - _Cutout) > 0.5 ? (1.0 - (1.0 - 2.0 * ((1.0 - _Cutout) - 0.5)) * ( 1.0 - RT_USSECCUT_OO_2)) : (2.0 * (1.0 - _Cutout) * RT_USSECCUT_OO_2))), _AlphaBaseCutout);
			RTD_CO = RTD_CO_ON;

			//GLOW
                #ifdef N_F_COEDGL_ON
				half _Glow_Edge_Width_Val = (1.0 - _Glow_Edge_Width);
				half _Glow_Edge_Width_Add_Input_Value = (_Glow_Edge_Width_Val + RTD_CO);
				half _Remapping = (_Glow_Edge_Width_Add_Input_Value * 8.0 + -4.0);
				half _Pre_Output = (1.0 - saturate(_Remapping));
				half3 _Final_Output = (_Pre_Output * lerp(0.0, _Glow_Color.rgb, saturate(_Cutout * 200.0))  );
				GLO_OUT = _Final_Output;
                #endif

			clip(RTD_CO - 0.5);

                #else

			half4 _MaskTransparency_var = SAMPLE_TEXTURE2D(_MaskTransparency, sampler_MaskTransparency, TRANSFORM_TEX(uv, _MaskTransparency));

			//Backup (Old)
			//half RTD_TRAN_MAS = (smoothstep(clamp(-20.0, 1.0, _TransparentThreshold), 1.0, _MainTex_var.a) * _MaskTransparency_var.r);
			//RTD_TRAN_OPA_Sli = lerp(RTD_TRAN_MAS, smoothstep(clamp(-20.0, 1.0, _TransparentThreshold), 1.0, _MainTex_var.a), _Opacity);

                #ifdef N_F_SIMTRANS_ON
				RTD_TRAN_OPA_Sli = _MainTex_var.a * _Opacity; //Early Added
                #else
				RTD_TRAN_OPA_Sli = lerp(smoothstep(clamp(-20.0, 1.0, _TransparentThreshold), 1.0, _MainTex_var.a) * _Opacity, 1.0, _MaskTransparency_var.r);
                #endif

                #endif

                #endif
                //------
            	
                #if N_F_TRANS_ON
                #ifndef N_F_CO_ON
					clip(RTD_TRAN_OPA_Sli - 0.5);
                #endif
                #endif


                #ifndef N_F_OFLMB_ON
                half3 lightColor = mainLight.color.rgb;
                #else
				half3 lightColor = (half3)1.0;
                #endif

                uint meshRenderingLayers = GetMeshRenderingLayer(); //

                #ifndef N_F_OFLMB_ON
                #ifdef _ADDITIONAL_LIGHTS
                #if N_F_EAL_ON

						uint pixelLightCount = GetAdditionalLightsCount();

						//
                #if USE_FORWARD_PLUS

							InputData inputData = (InputData)0;
							inputData.positionWS = positionWS;
							inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

							for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
							{
								Light light = GetAdditionalLight(lightIndex, input.posWorld.xyz, (float4)1.0);

                #ifdef _LIGHT_LAYERS
								if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
								{
									lightColor += light.color * light.distanceAttenuation;
								}
							}
                #endif
						//

						LIGHT_LOOP_BEGIN(pixelLightCount)
							Light light = GetAdditionalLight(lightIndex, positionWS);

                #ifdef _LIGHT_LAYERS//
								if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif//
							{
								lightColor += light.color * light.distanceAttenuation;
							}
						LIGHT_LOOP_END

                #endif
                #endif
                #endif


                float fogFactor = input.positionWSAndFogFactor.w;


                //
                #ifdef UNITY_COLORSPACE_GAMMA
				_OutlineColor = float4(LinearToGamma22(_OutlineColor.rgb), _OutlineColor.a);
                #endif

                half3 RTD_MMTTO_OO;
                if (!_MixMainTexToOutline)
                {
                    RTD_MMTTO_OO = _OutlineColor.rgb;
                }
                else
                {
                    RTD_MMTTO_OO = _OutlineColor.rgb * _MainTex_var.rgb;
                }

                half3 RTD_OL_LAOC_OO;
                if (!_LightAffectOutlineColor)
                {
                    RTD_OL_LAOC_OO = RTD_MMTTO_OO;
                }
                else
                {
                    RTD_OL_LAOC_OO = lerp(half3(0.0, 0.0, 0.0), RTD_MMTTO_OO, lightColor.rgb);
                }

                //


                half3 finalRGBA = RTD_OL_LAOC_OO;

                //RT_NFD
                #ifdef N_F_NFD_ON
				RT_NFD(input.positionCS);
                #endif

                color = MixFog(finalRGBA, fogFactor);

                #if defined(N_F_TRANS_ON) & !defined(N_F_CO_ON)
				outColor = half4(color, RTD_TRAN_OPA_Sli);
                #else
                outColor = half4(color, 1.0);
                #endif
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

            float4 frag(Varyings i) : SV_Target
            {
                return float4(1, 1, 1, 1);
            }
            ENDHLSL

        }


    }

    FallBack "Hidden/InternalErrorShader"

}