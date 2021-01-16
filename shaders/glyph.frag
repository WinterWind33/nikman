#version 330 core
out vec4 FragColor;

in vec2 texCoord;
uniform sampler2D fontTexture;
uniform vec3 color;

void main()
{
    float alpha = texture(fontTexture, texCoord).a;
    FragColor = vec4(color, alpha);
} 