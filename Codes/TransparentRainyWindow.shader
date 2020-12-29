Shader "MyOwn/TransparentRainyWindow"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Size("Size",range(-50,50)) = 5
        _T("Time", float) = 1
        _Distortion("Distortion", range(-5,5)) = 1
        _Blur("Blur", range(0,1)) = 1
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque"  "QUeue" = "Transparent"}   //Transparent here means rendered after all other geometry objects
            LOD 100

            GrabPass{"_GrabTexture"}   //render the scene it is and make it available as a texture for further use
            //as a sampler2D

            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                // make fog work
                #pragma multi_compile_fog

                #include "UnityCG.cginc"
                #define S(a,b,t) smoothstep(a, b, t)

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    float4 grabuv: TEXCOORD1;   // unity_proj_coord float 4
                    UNITY_FOG_COORDS(1)
                    float4 vertex : SV_POSITION;
                };

                sampler2D _MainTex, _GrabTexture;
                float4 _MainTex_ST;
                float _Size, _T, _Distortion, _Blur;
                v2f vert(appdata v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                    //screen captured UV
                    o.grabuv = UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex));  //utilize screen pose for proper uv
                    UNITY_TRANSFER_FOG(o,o.vertex);
                    return o;
                }

                float N21(float2 p) {
                    //psudo-randomi value
                    p = frac(p * float2(123.34, 345.45));
                    p += dot(p, p + 34.345);
                    return frac(p.x * p.y);
                }

                //For Processing the dropping
                float3 Layer(float2 UV, float t)
                {

                    //grid is higher in y coord
                    float2 aspect = float2(2.0, 1.0);
                    float2 uv = UV * _Size * aspect;
                    uv.y += t * .25;  //tweak to fit the dropping speed
                    //frac component of uv, only wanna the numbers after dot
                    float2 gv = frac(uv) - .5;  //make the origin of the box at the center   

                    float2 id = floor(uv);  //get access to the box
                    float n = N21(id); //return a random number between 0 - 1
                    t += n * 6.2831;  //randomize the time with pi
                     //simulate the x distortion using sin(x) as well
                    float w = UV.y * 9;
                    float x = (n - 0.5) * 0.8;   // -0.4 to 0.4
                    x += (.4 - abs(x)) * sin(3 * w) * pow(sin(w), 6) * .45;  //add more bias
                    float y = -sin(t + sin(t + sin(t) * 0.5)) * 0.45;
                    y += (gv.x - x) * (gv.x - x);  //minor edition for the center drop


                    float2 dropPos = (gv - float2(x, y)) / aspect;
                    float2 trailPos = (gv - float2(x, t * .25)) / aspect;   //trail in the middle
                    trailPos.y = (frac(trailPos.y * 8) - .5) / 8;  // /8 to get rid of distortion
                    float trail = S(0.03, 0.01, length(trailPos));
                    float drop = S(0.05, 0.03, length(dropPos));  //distance to the center, only wanna the center

                    float fogTrail = S(-0.05, 0.05, dropPos.y);  // make sure the trail is alwasy above the center dropPos
                    fogTrail *= S(.5, y, gv.y);   //faded-color trail
                    fogTrail *= S(.05, .04, abs(dropPos.x));
                    trail *= fogTrail;

                    //background offset textures for dropping
                    //col += fogTrail * .5;
                    //col += drop;
                    //col += trail;
                    float2 offs = drop * dropPos + trail * trailPos;

                    return float3(offs, fogTrail);
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    //make sure the time won't be too large
                    float t = fmod(_Time.y + _T, 7200);  // time.y increased one each step
                    float4 col = 0.0f;

                    //if (gv.x > 0.48 || gv.y>0.49) col = float4(1, 0, 0, 1);  //obtain the red grid
                    //col *= 0; col += N21(id);

                    //add offset here with maintextures
                    float3 drops = Layer(i.uv, t);
                    drops += Layer(i.uv * 1.23 + 7.54, t);
                    drops += Layer(i.uv * 1.35 + 1.54, t);   //more drops
                    drops += Layer(i.uv * 1.57 + 7.54, t);
                    //saturate is the clamp between 0 and 1, fade is used for far way effects
                    float fade = 1-saturate(fwidth(i.uv) * 50);   //fwidth - get the difference of any variable with the nerighboring pixels
                    float blur = _Blur * 7 * (1 - drops.z * fade);   //only clear for the fogtrail
                    col = tex2Dlod(_MainTex, float4(i.uv + drops.xy * _Distortion, 0, blur));  //mip map used, if the last parameter is larger than 1, smaller texture will be used and blurred effects
                    
                    float2 projUV = i.grabuv.xy / i.grabuv.w;   //manual way of tex2Dproj
                    const float numSamples = 16;
                    projUV += drops.xy * _Distortion * fade;  //drag the drops back
                    blur *= .01;
                    float a = N21(i.uv)*6.2831;
                    for (float i = 0; i < numSamples; i++)
                    {
                        float2 offs = float2(sin(a), cos(a)) * blur;
                        float d = frac(sin((i + 1) * 546.) * 5424.);  //multiply a semi psudo-random number, make the blur softer 
                        d = sqrt(d);
                        offs  *=d;
                        col += tex2D(_GrabTexture, projUV+offs);
                        a++;  //rotate the offs a little bit
                        //add some bias for blur
                    }
                    col /= numSamples;
                    //col = tex2Dproj(_GrabTexture, i.grabuv);   
                    return col;
                }
                ENDCG
            }
        }
}
