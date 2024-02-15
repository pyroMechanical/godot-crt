shader_type spatial;
render_mode unshaded;

uniform sampler2D INPUT: source_color, filter_nearest;

float i_carrier(vec2 uv, float amplitude) {
	float offset = 0.0;
	if (int(uv.y * 480.0) % 2 == 1) {
		offset = 0.5;
	}
	return amplitude * sin(910.0*PI*(uv.x + offset));
}

float q_carrier(vec2 uv, float amplitude) {
	float offset = 0.0;
	if (int(uv.y * 480.0) % 2 == 1) {
		offset = 0.5;
	}
	return amplitude * cos(910.0*PI*(uv.x + offset));
}

float normalized_to_ire(float normalized) {
	return (1.6 * normalized) - 0.4;
}

vec3 rgb_to_ire(vec3 color) {
	return (color * .925) + .075;
}

float ire_to_normalized(float ire) {
	return (ire+0.4)/1.6;
}

vec3 rgb_to_yiq(vec3 rgb) {
	vec3 ire = rgb_to_ire(rgb);
	float y = 0.3 * ire.r + 0.59 * ire.g + 0.11 * ire.b;
	float i = -0.27 * (ire.b - y) + 0.74 * (ire.r - y);
	float q = 0.41 * (ire.b - y) + 0.48 * (ire.r - y);
	return vec3(y, i, q);
}

vec3 ire_to_color(float ire) {
	float channel1 = ire;
	if (channel1 < 0.0) {channel1 = 0.0;}
	float channel2 = -ire;
	if (channel2 < 0.0) {channel2 = 0.0;}
	
	return vec3(channel2 + channel1, channel1, channel1);
}

vec2 true_uv(vec2 uv) {
	int active_video = 52600;
	int line = 63500;
	float ratio = float(line)/float(active_video);
	float difference = float(line-active_video)/float(line);
	return vec2((uv.x - difference)*ratio, uv.y);
}

void fragment() {
	int signal = int(UV.x * 63500.0);
	if(signal % 63500 <= 1500) {
		ALBEDO = ire_to_color(0.0);
	}
	else if (signal % 63500 <= 1500 + 4700) {
		ALBEDO = ire_to_color(-0.4);
	}
	else if (signal % 63500 <= 1500 + 4700 + 600) {
		ALBEDO = ire_to_color(0.0);
	}
	else if (signal % 63500 <= 1500 + 4700 + 600 + 2500) {
		ALBEDO = ire_to_color(i_carrier(UV, 0.2));
	}
	else if (signal % 63500 <= 1500 + 4700 + 600 + 2500 + 1600) {
		ALBEDO = ire_to_color(0.0);
	}
	else {
		vec3 yiq = rgb_to_yiq(texture(INPUT, true_uv(UV)).rgb);
		float result = yiq.x + i_carrier(UV, yiq.y) + q_carrier(UV, yiq.z);
		ALBEDO = ire_to_color(result);
	}
}
