using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine;
using UnityEngine.UIElements;

namespace NKStudio
{
    // 초기에 상황에 맞게 똑똑한 Sync 방향을 할 수 있도록 했었으나
    // 재질의 타일링 값과 Material Data의 타일링 값을 바꿔도 잘 작동하며, Revert라던가, 렌더러 변경 등 다양한 예외상황을 모두 코딩으로 하려나 너무 지저분해져서
    // 작업자가 수동으로 Sync 방향을 정하도록 함.
    [CanEditMultipleObjects]
    [CustomEditor(typeof(MaskObjectLinker))]
    public class MaskObjectLinkerEditor : Editor
    {
        // SerializedProperty
        private SerializedProperty _meshRendererProperty;
        private SerializedProperty _editorPlayProperty;
        private SerializedProperty _originMaterialProperty;

        // VisualElement
        private VisualElement _root;
        private PropertyField _moveObjectField;
        private HelpBox _infoBox;
        private Button _editorPlayButton;

        private StyleSheet _styleSheet;

        // Target
        private MaskObjectLinker _maskObjectLinker;

        private void OnEnable()
        {
            _maskObjectLinker = target as MaskObjectLinker;
            string path = AssetDatabase.GUIDToAssetPath("340037ff3a85333439aa72527fc4fcf8");
            _styleSheet = AssetDatabase.LoadAssetAtPath<StyleSheet>(path);
        }

        public override VisualElement CreateInspectorGUI()
        {
            FindProperties();

            // Root
            _root = new VisualElement();
            _root.styleSheets.Add(_styleSheet);

            // Element
            _moveObjectField = new PropertyField();
            _moveObjectField.BindProperty(_meshRendererProperty);

            _editorPlayButton = new Button();
            _editorPlayButton.style.marginTop = 5;
            _editorPlayButton.style.height = 32;
            const int radius = 12;
            _editorPlayButton.style.borderTopLeftRadius = radius;
            _editorPlayButton.style.borderTopRightRadius = radius;
            _editorPlayButton.style.borderBottomLeftRadius = radius;
            _editorPlayButton.style.borderBottomRightRadius = radius;
            _editorPlayButton.tooltip = "에디터에서 작업 및 테스트하려면 이 기능을 활성화 해주세요.\n단, 실제로 런타임 모드일 때는 이 기능을 해제 하십시오.";

            var title = new Label("Mask Object Linker");
            title.AddToClassList("TitleStyle");

            var group = new GroupBox();
            group.AddToClassList("GroupBoxStyle");

            _infoBox = new HelpBox
            {
                messageType = HelpBoxMessageType.Warning,
                text = "Editor Play는 에디터에서 작업할 때만 활성화 해주세요.\n런타임 모드에서는 비활성화 해주세요.",
            };
            _infoBox.SetActive(false);

            _root.Add(title);
            _root.Add(group);
            group.Add(_moveObjectField);
            group.Add(_infoBox);
            _root.Add(_editorPlayButton);

            RefreshMoveObjectField();
            RefreshButtonStyle(_editorPlayButton);
            RefreshActiveHelpBox();

            title.RegisterCallback<ClickEvent>(_ => MaskObjectLinkerEditorUtility.OpenBehaviour(_maskObjectLinker));
            _editorPlayButton.clicked += () => OnClickPlayModeButton(_editorPlayButton);

            return _root;
        }

        /// <summary>
        /// MoveObject를 리프래쉬 합니다.
        /// </summary>
        private void RefreshMoveObjectField()
        {
            if (EditorApplication.isPlaying)
                _moveObjectField.SetEnabled(false);
            else
                _moveObjectField.SetEnabled(true);
        }

        /// <summary>
        /// 플레이 모드 버튼을 눌렀을 때 처리
        /// </summary>
        /// <param name="element"></param>
        private void OnClickPlayModeButton(VisualElement element)
        {
            // 값을 반전 합니다.
            _editorPlayProperty.boolValue = !_editorPlayProperty.boolValue;

            // 기타 처리
            EnsureSystemStability();
            RefreshButtonStyle(element);
            RefreshActiveHelpBox();
            serializedObject.ApplyModifiedProperties();
        }

        /// <summary>
        /// 플레이 모드가 되면 경고  박스를 띄운다.
        /// </summary>
        private void RefreshActiveHelpBox()
        {
            _infoBox.SetActive(IsEditorPlayMode());
        }

        /// <summary>
        /// 버튼에 대한 스타일 처리
        /// </summary>
        /// <param name="element"></param>
        private void RefreshButtonStyle(VisualElement element)
        {
            // True라면,
            if (IsEditorPlayMode())
            {
                _editorPlayButton.text = "Exit";
                if (EditorGUIUtility.isProSkin)
                    element.AddToClassList("ButtonActive_dark");
                else
                    element.AddToClassList("ButtonActive_white");
            }
            else
            {
                _editorPlayButton.text = "Play";
                if (EditorGUIUtility.isProSkin)
                    element.RemoveFromClassList("ButtonActive_dark");
                else
                    element.RemoveFromClassList("ButtonActive_white");
            }

            // 유니티가 프레이 모드라면 버튼을 비활성화 시킴
            if (EditorApplication.isPlaying)
                element.SetEnabled(false);
            else
                element.SetEnabled(true);
        }

        /// <summary>
        /// 플레이 모드가 되면 인스턴스를 생성하고, 플레이모드를 종료하면 인스턴스를 생성한 것을 삭제한다.
        /// </summary>
        private void EnsureSystemStability()
        {
            // true라면 에디터에서 작업을 시작합니다.
            bool playMode = _editorPlayProperty.boolValue;

            // 플레이 모드라면 
            if (playMode)
            {
                // 인스턴스 머티리얼로 변경합니다.
                ChangeInstanceMaterial();
            }
            // 플레이 모드가 아니라면,
            else
            {
                // 트레일 렌더러에 있는 머티리얼을 원래대로 되돌린다.
                // 만약 리스트 공간은 있는데, 트레일이 연결이 안되어 있을 수 도 있다.
                MeshRenderer targetRender = (MeshRenderer)_meshRendererProperty.objectReferenceValue;

                if (targetRender)
                {
                    // 머티리얼을 리셋
                    RestMaterial(targetRender);
                }
            }
        }

        /// <summary>
        /// 머티리얼 데이터 리스트에 Index로 이동하여 해당 트레일 렌더러에 접근하고,
        /// m_Materials에 접근해서 0번째 머티리얼을 인스턴스 머티리얼로 변경한다.
        /// </summary>
        private void ChangeInstanceMaterial()
        {
            // 타겟 렌더러
            MeshRenderer targetRenderer = (MeshRenderer)_meshRendererProperty.objectReferenceValue;

            // 없으면 리턴
            if (targetRenderer == null)
                return;

            // 머티리얼 프로퍼티 접근
            Material sharedMaterial = targetRenderer.sharedMaterial;
            _originMaterialProperty.objectReferenceValue = sharedMaterial;

            // 0번째 머리티얼을 인스턴스 머티리얼로 변경한다.
            targetRenderer.sharedMaterial = Instantiate(sharedMaterial);

            // 캐쉬 머티리얼을 만들어서 저장한다.
            _originMaterialProperty.serializedObject.ApplyModifiedProperties();
        }
        
        /// <summary>
        /// 머티리얼을 원래 머티리얼로 되돌립니다.
        /// 인스턴스 머티리얼을 제거하고, 프리팹 오브젝트라면 원래대로 되돌리고, 일반 오브젝트라면 원래 머티리얼로 되돌립니다.
        /// </summary>
        /// <param name="targetRenderer">원래대로 되돌릴 트레일 렌더러</param>
        private void RestMaterial(MeshRenderer targetRenderer)
        {
            // 인스턴스 머티리얼을 사용하고 있다면 제거한다.
            string isInstanceMaterial = AssetDatabase.GetAssetPath(targetRenderer.sharedMaterial);
            if (string.IsNullOrWhiteSpace(isInstanceMaterial))
            {
                DestroyImmediate(targetRenderer.sharedMaterial);
                targetRenderer.sharedMaterial = null;
            }
            
            // 원래 머티리얼로 되돌리기
            targetRenderer.sharedMaterial = (Material)_originMaterialProperty.objectReferenceValue;
            _originMaterialProperty.objectReferenceValue = null;
        }

        /// <summary>
        /// 프로퍼티를 찾습니다.
        /// </summary>
        private void FindProperties()
        {
            _meshRendererProperty = serializedObject.FindProperty("MeshRenderer");
            _editorPlayProperty = serializedObject.FindProperty("editorPlayMode");
            _originMaterialProperty = serializedObject.FindProperty("Origin");
        }

        /// <summary>
        /// 에디터 플레이 모드가 실행되어 있는지 체크
        /// </summary>
        /// <returns>켜져있으면 true를 반환, 아닐시 false를 반환</returns>
        private bool IsEditorPlayMode() => _editorPlayProperty.boolValue;
        
    }
}