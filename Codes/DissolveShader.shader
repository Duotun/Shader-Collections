Shader "MyOwn/DissolveShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        //Dissolve Poperties - dark parts dissolve with a lower value
        _DissolveTexture("Dissolve Texture", 2D) = "white"{}
        _Amount("Amount", Range(0,1))= 0
        _BurnSize("Burn Size", Range(0.0, 1.0)) = 0.15
        _BurnRamp("Burn Ramp (RGB)", 2D) = "white" {}
        _BurnColor("Burn Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        // Dissolve properties - name match
        sampler2D _DissolveTexture;
        half _Amount;
        sampler2D _BurnRamp;
        fixed4 _BurnColor;
        float _BurnSize;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            half dissolve_value = tex2D(_DissolveTexture, IN.uv_MainTex).rgb;
            clip(dissolve_value - _Amount);

            if (dissolve_value - _Amount < _BurnSize && _Amount > 0) {
                o.Emission = tex2D(_BurnRamp, float2(dissolve_value - _Amount * (1 / _BurnSize), 0)) * _BurnColor;
            }

            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
