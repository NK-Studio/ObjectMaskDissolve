using System;
using UnityEngine;

namespace NKStudio
{
    public class MaskObjectLinker : MonoBehaviour
    {
        private Mesh _planeMesh;
        public MeshRenderer MeshRenderer;
        private static readonly int DissolveOffset = Shader.PropertyToID("_DissolveOffset");
        private static readonly int DissolveDirection = Shader.PropertyToID("_DissolveDirection");

        private void Update()
        {
            Vector3 posOffset = transform.position - MeshRenderer.transform.position;
            Quaternion rotOffset = Quaternion.Inverse(MeshRenderer.transform.rotation) * transform.rotation;
            
            
            MeshRenderer.material.SetVector(DissolveOffset, posOffset);
            MeshRenderer.material.SetVector(DissolveDirection, rotOffset * Vector3.forward);
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
    }
}