using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace NKStudio
{
    [ExecuteAlways]
    public class MaskObjectLinker : MonoBehaviour
    {
        private Mesh _planeMesh;
        public MeshRenderer MeshRenderer;
        private static readonly int DissolveOffset = Shader.PropertyToID("_DissolveOffset");
        private static readonly int DissolveDirection = Shader.PropertyToID("_DissolveDirection");

#if UNITY_EDITOR
        // 에디터에서 플레이 시킬 때 사용
        [SerializeField] private bool editorPlayMode;

        public Material Origin;
#endif

        private void Start()
        {
#if UNITY_EDITOR
            // 유니티의 플레이 모드 상태에서 TrailFX의 플레이 모드가 켜져있으면 안된다.
            if (IsPlayMode)
                StartCoroutine(EnsureSystemStability());

            if (editorPlayMode)
                return;
#endif

            if (!MeshRenderer)
                return;

            if (IsPlayMode)
            {
                // 인스턴싱 머티리얼을 트레일 렌더러에 적용
                MeshRenderer.material = MeshRenderer.material;
            }
        }

        private void Update()
        {
#if UNITY_EDITOR
            if (IsEditorMode)
            {
                if (!editorPlayMode)
                    return;
            }
#endif

            if (!MeshRenderer)
            {
                Debug.LogWarning("MeshRenderer가 연결되어 있지 않습니다.");
                return;
            }

            Vector3 posOffset = transform.position - MeshRenderer.transform.position;
            Quaternion rotOffset = Quaternion.Inverse(MeshRenderer.transform.rotation) * transform.rotation;

            if (IsPlayMode)
            {
                MeshRenderer.material.SetVector(DissolveOffset, posOffset);
                MeshRenderer.material.SetVector(DissolveDirection, rotOffset * Vector3.forward);
            }
            else
            {
                MeshRenderer.sharedMaterial.SetVector(DissolveOffset, posOffset);
                MeshRenderer.sharedMaterial.SetVector(DissolveDirection, rotOffset * Vector3.forward);
            }
        }

        private void OnDestroy()
        {
            if (IsPlayMode)
            {
                CoreUtils.Destroy(MeshRenderer.material);
            }
        }


        private void OnDrawGizmosSelected()
        {
            if (!_planeMesh)
            {
                _planeMesh = new Mesh
                {
                    vertices = new Vector3[4]
                    {
                        new Vector3(-1, -1),
                        new Vector3(-1, 1),
                        new Vector3(1, 1),
                        new Vector3(1, -1)
                    },
                    triangles = new[]
                    {
                        0, 1, 2,
                        0, 2, 3,

                        // backfaces
                        0, 2, 1,
                        0, 3, 2
                    },
                    normals = new Vector3[4]
                    {
                        Vector3.forward,
                        Vector3.forward,
                        Vector3.forward,
                        Vector3.forward,
                    }
                };
            }


            // 플랜 기즈모 그리기
            Gizmos.color = Color.red;
            Gizmos.DrawWireMesh(_planeMesh, transform.position, transform.rotation,
                transform.localScale);
        }

        /// <summary>
        /// 에디터 모드인가?
        /// </summary>
        private static bool IsEditorMode => !Application.isPlaying;

        /// <summary>
        /// 플레이 모드인가?
        /// </summary>
        private static bool IsPlayMode => Application.isPlaying;

#if UNITY_EDITOR
        private IEnumerator EnsureSystemStability()
        {
            yield return new WaitForSeconds(0.1f);

            if (editorPlayMode)
            {
                EditorApplication.isPlaying = false;
                Debug.LogError($"{gameObject.name}에 Editor Play 모드가 켜져있습니다.");
            }
        }
#endif
    }
}