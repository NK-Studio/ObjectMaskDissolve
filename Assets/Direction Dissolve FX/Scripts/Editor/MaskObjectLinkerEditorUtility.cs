using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

namespace NKStudio
{
    public static class MaskObjectLinkerEditorUtility
    {
        private static VisualElement _cachedContextWidthElement;
        private static VisualElement _cachedInspectorElement;
        
        internal static void SetActive(this VisualElement field, bool active)
        {
            field.style.display = active ? DisplayStyle.Flex : DisplayStyle.None;
            field.style.visibility = active ? Visibility.Visible : Visibility.Hidden;
        }
        
        internal static void OpenBehaviour(MonoBehaviour targetBehaviour)
        {
            var scriptAsset = MonoScript.FromMonoBehaviour(targetBehaviour);
            var path = AssetDatabase.GetAssetPath(scriptAsset);

            TextAsset textAsset = AssetDatabase.LoadAssetAtPath<TextAsset>(path);
            AssetDatabase.OpenAsset(textAsset);
        }
    }
}