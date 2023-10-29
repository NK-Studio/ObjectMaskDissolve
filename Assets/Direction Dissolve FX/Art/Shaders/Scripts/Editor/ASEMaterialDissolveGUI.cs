#if UNITY_EDITOR
using System;
using UnityEditor;
using UnityEditor.Rendering.Universal.ShaderGUI;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace NKStudio
{
    public class ASEMaterialDissolveGUI : BaseShaderGUI
    {
        private MaterialProperty _metallic;
        private MaterialProperty _metallicGlossMap;
        private MaterialProperty _smoothness;
        private MaterialProperty _smoothnessMapChannel;
        private MaterialProperty _bumpMapProp;
        private MaterialProperty _bumpScaleProp;
        private MaterialProperty _parallaxMapProp;
        private MaterialProperty _parallaxScaleProp;
        private MaterialProperty _occlusionStrength;
        private MaterialProperty _occlusionMap;
        private MaterialProperty _highlights;
        private MaterialProperty _reflections;

        // Dissolve
        private MaterialProperty _edgeWidth;
        private MaterialProperty _edgeColor;
        private MaterialProperty _edgeColorIntensity;
        private MaterialProperty _noiseScale;
        private MaterialProperty _dissolveOffset;
        private MaterialProperty _BOOLEAN_DIRECTION_FROM_EULERANGLE;
        private MaterialProperty _dissolveDirection;
        private MaterialProperty _noiseUVSpeed;
        private MaterialProperty _directionEdgeWidthScale;

        private static readonly GUIContent DitherTex =
            new GUIContent("Dither", "Dither recommends an Alpha Clipping Threshold of 1f.");

        private static readonly GUIContent DitherErrorTex =
            new GUIContent("Dither (Require Alpha Clipping)", "Available only when 'Alpha Clipping' is enabled.");

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);

            // additional Props
            _metallic = FindProperty("_Metallic", properties);
            _metallicGlossMap = FindProperty("_MetallicGlossMap", properties);
            _smoothness = FindProperty("_Smoothness", properties);
            _smoothnessMapChannel = FindProperty("_SmoothnessTextureChannel", properties);
            _bumpMapProp = FindProperty("_BumpMap", properties);
            _bumpScaleProp = FindProperty("_BumpScale", properties);
            _parallaxMapProp = FindProperty("_ParallaxMap", properties);
            _parallaxScaleProp = FindProperty("_Parallax", properties);
            _occlusionStrength = FindProperty("_OcclusionStrength", properties);
            _occlusionMap = FindProperty("_OcclusionMap", properties);

            // Advanced Props
            _highlights = FindProperty("_SpecularHighlights", properties);
            _reflections = FindProperty("_EnvironmentReflections", properties);

            // Dissolve Props
            _edgeWidth = FindProperty("_EdgeWidth", properties);
            _edgeColor = FindProperty("_EdgeColor", properties);
            _edgeColorIntensity = FindProperty("_EdgeColorIntensity", properties);
            _noiseScale = FindProperty("_NoiseScale", properties);
            _dissolveOffset = FindProperty("_DissolveOffset", properties);
            _BOOLEAN_DIRECTION_FROM_EULERANGLE = FindProperty("BOOLEAN_DIRECTION_FROM_EULERANGLE", properties);
            _dissolveDirection = FindProperty("_DissolveDirection", properties);
            _directionEdgeWidthScale = FindProperty("_DirectionEdgeWidthScale", properties);
            _noiseUVSpeed = FindProperty("_NoiseUVSpeed", properties);
        }

        public override void OnGUI(MaterialEditor materialEditorIn, MaterialProperty[] properties)
        {
            if (materialEditorIn == null)
                throw new ArgumentNullException("materialEditorIn");

            materialEditor = materialEditorIn;
            Material material = materialEditorIn.target as Material;

            // Find the property.
            FindProperties(properties);

            // Draw the GUI.
            DrawNKLitShaderGUI(material);
        }

        public override void ValidateMaterial(Material material)
        {
            SetMaterialKeywords(material, LitGUI.SetMaterialKeywords);
        }

        private void DrawNKLitShaderGUI(Material material)
        {
            DrawHeader("Lit Dissolve + Outline");

            EditorGUI.BeginChangeCheck();
            {
                GUILayout.Space(3);
                InspectorBox(10, () =>
                {
                    EditorGUILayout.LabelField(Styles.SurfaceOptions, EditorStyles.boldLabel);
                    DrawFloatToggleProperty(Styles.alphaClipText, alphaClipProp);

                    if ((alphaClipProp != null) && (alphaCutoffProp != null) && (alphaClipProp.floatValue == 1))
                        materialEditor.ShaderProperty(alphaCutoffProp, Styles.alphaClipThresholdText, 1);
                });

                EditorGUILayout.Separator();
                InspectorBox(10, () =>
                {
                    EditorGUILayout.LabelField(Styles.SurfaceInputs, EditorStyles.boldLabel);

                    GUILayout.Space(5); // ----------------------------------------------------------------------

                    materialEditor.TexturePropertySingleLine(Styles.baseMap, baseMapProp, baseColorProp);

                    GUILayout.Space(5); // ----------------------------------------------------------------------

                    materialEditor.TexturePropertySingleLine(new GUIContent("Metallic"),
                        _metallicGlossMap, _metallicGlossMap.textureValue == null ? _metallic : null);

                    GUILayout.Space(5); // ----------------------------------------------------------------------

                    string[] smoothnessChannelNames = LitGUI.Styles.metallicSmoothnessChannelNames;

                    LitGUI.DoSmoothness(materialEditor, material, _smoothness, _smoothnessMapChannel,
                        smoothnessChannelNames);

                    GUILayout.Space(5); // ----------------------------------------------------------------------

                    DrawNormalArea(materialEditor, _bumpMapProp, _bumpScaleProp);

                    materialEditor.TexturePropertySingleLine(LitGUI.Styles.heightMapText,
                        _parallaxMapProp,
                        _parallaxMapProp.textureValue != null ? _parallaxScaleProp : null);

                    materialEditor.TexturePropertySingleLine(LitGUI.Styles.occlusionText, _occlusionMap,
                        _occlusionMap.textureValue != null ? _occlusionStrength : null);

                    DrawEmissionProperties(material, true);

                    materialEditor.TextureScaleOffsetProperty(baseMapProp);
                });

                EditorGUILayout.Separator();
                InspectorBox(10, () =>
                {
                    EditorGUILayout.LabelField("Dissolve System", EditorStyles.boldLabel);
                    EditorGUI.BeginDisabledGroup(alphaClipProp.floatValue == 0);
                    materialEditor.ShaderProperty(_edgeWidth, "Edge Width");
                    materialEditor.ShaderProperty(_directionEdgeWidthScale, "Direction Edge Width Scale");
                    materialEditor.ShaderProperty(_noiseScale, "Noise Scale");
                    EditorGUILayout.Space(3);
                    materialEditor.ShaderProperty(_edgeColor, "Edge Color");
                    materialEditor.ShaderProperty(_edgeColorIntensity, "Edge Color Intensity");
                    EditorGUILayout.Space(3);
                    _noiseUVSpeed.vectorValue =
                        EditorGUILayout.Vector2Field(_noiseUVSpeed.displayName, _noiseUVSpeed.vectorValue);
                    _dissolveOffset.vectorValue =
                        EditorGUILayout.Vector3Field(_dissolveOffset.displayName, _dissolveOffset.vectorValue);
                    _dissolveDirection.vectorValue = EditorGUILayout.Vector3Field(_dissolveDirection.displayName,
                        _dissolveDirection.vectorValue);
                    materialEditor.ShaderProperty(_BOOLEAN_DIRECTION_FROM_EULERANGLE, "Direction From Euler Angle");
                    EditorGUI.EndDisabledGroup();
                    
                    GUILayout.Space(5); // ----------------------------------------------------------------------
                });

                EditorGUILayout.Separator(); // ------------------------------------------------------------------------

                InspectorBox(10, () =>
                {
                    GUILayout.Label(Styles.AdvancedLabel, EditorStyles.boldLabel);
                    DrawAdvancedOptions(material);
                });
            }
        }

        /// <summary>
        /// 하이라이팅과 리플랙션 반사에 대한 토글 체크 표시 및 렌더링 큐를 설정합니다.
        /// </summary>
        /// <param name="material"></param>
        public override void DrawAdvancedOptions(Material material)
        {
            if (_reflections != null && _highlights != null)
            {
                materialEditor.ShaderProperty(_highlights, LitGUI.Styles.highlightsText);
                materialEditor.ShaderProperty(_reflections, LitGUI.Styles.reflectionsText);
            }

            // Only draw the sorting priority field if queue control is set to "auto"
            base.DrawAdvancedOptions(material);
        }

        private void DrawHeader(string name)
        {
            // Init
            GUIStyle rolloutHeaderStyle = new GUIStyle(GUI.skin.box);
            rolloutHeaderStyle.fontStyle = FontStyle.Bold;
            rolloutHeaderStyle.normal.textColor = EditorGUIUtility.isProSkin ? Color.white : Color.black;

            // Draw
            GUILayout.Label(name, rolloutHeaderStyle, GUILayout.Height(24), GUILayout.ExpandWidth(true));
        }

        private static void InspectorBox(int aBorder, System.Action inside)
        {
            Rect r = EditorGUILayout.BeginHorizontal();

            GUI.Box(r, GUIContent.none);
            GUILayout.Space(aBorder);
            EditorGUILayout.BeginVertical();
            GUILayout.Space(aBorder);
            inside();
            GUILayout.Space(aBorder);
            EditorGUILayout.EndVertical();
            GUILayout.Space(aBorder);
            EditorGUILayout.EndHorizontal();
        }
    }
}

#endif