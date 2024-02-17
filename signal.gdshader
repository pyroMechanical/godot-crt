shader_type spatial;
render_mode unshaded;

uniform sampler2D INPUT: source_color, filter_linear_mipmap_anisotropic, repeat_disable;

vec2 true_uv(vec2 uv) {
	int active_video = 52600;
	int line = 63500;
	float ratio = float(line)/float(active_video);
	float difference = float(line-active_video)/float(line);
	return vec2((uv.x - difference)*ratio, uv.y);
}

vec3 gamma(vec3 rgb) {
	return mix(pow((rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)),vec3(2.4)),rgb.rgb * (1.0 / 12.92),lessThan(rgb,vec3(0.04045)));
}

float i_carrier(vec2 uv, float amplitude) {
	float offset = 0.0;
	if (int(true_uv(uv).y * 480.0 + (TIME*60.0)) % 2 == 1) {
		offset = 0.5;
	}
	return amplitude * sin(910.0*PI*(uv.x + offset));
}

float q_carrier(vec2 uv, float amplitude) {
	float offset = 0.0;
	if (int(true_uv(uv).y * 480.0 + (TIME*60.0)) % 2 == 1) {
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

vec3 ire_to_rgb(vec3 ire) {
	return (ire - .075)/.925;
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

vec3 yiq_to_rgb(vec3 yiq) {
	float r = yiq.x + 0.9469 * yiq.y + 0.6236 * yiq.z;
	float g = yiq.x - 0.27478 * yiq.y - 0.6357 * yiq.z;
	float b = yiq.x - 1.1 * yiq.y + 1.7 * yiq.z;
	return vec3(r, g, b);
}

vec3 ire_to_color(float ire) {
	float channel1 = ire;
	if (channel1 < 0.0) {channel1 = 0.0;}
	float channel2 = -ire;
	if (channel2 < 0.0) {channel2 = 0.0;}
	
	return vec3(channel2 + channel1, channel1, channel1);
}

vec3 generate_video(vec2 uv) {
	const int SAMPLE_COUNT = 17;
		float samples[SAMPLE_COUNT];
		float bandpass_coefficients[SAMPLE_COUNT] = { -7.762856376370929e-19, -0.0036823385701536065, -0.01134289622152476, -0.016313834993615363, 5.239928054050373e-18, 0.05349070548312986, 0.1371203498238655, 0.21626492142639114, 0.24892618610381442, 0.21626492142639114, 0.1371203498238655, 0.053490705483129876, 5.239928054050373e-18, -0.016313834993615356, -0.01134289622152476, -0.00368233857015361, -7.762856376370929e-19};
		float i_coefficients[SAMPLE_COUNT] = {-0.017334671842483152, -0.023325273506176695, -0.03370467106243774, -0.03121057829862862, 0.0, 0.06224415844838667, 0.13957436541300114, 0.203896751952862, 0.22889837668354956, 0.203896751952862, 0.13957436541300114, 0.06224415844838669, 0.0, -0.031210578298628607, -0.03370467106243774, -0.02332527350617672, -0.017334671842483152};
		float q_coefficients[SAMPLE_COUNT] = {-0.018055419579658248, -0.024027469226145994, -0.03438946897309245, -0.031589723609457596, 0.0, 0.062271774148114925, 0.13913174637238748, 0.20280988287467533, 0.22751385085204134, 0.20280988287467533, 0.13913174637238748, 0.062271774148114946, 0.0, -0.03158972360945759, -0.03438946897309245, -0.024027469226146018, -0.018055419579658248};
		float chroma_i = 0.0;
		float chroma_q = 0.0;
		float luma = 0.0;
		for(int i = 0; i < SAMPLE_COUNT; i++) {
			vec2 temp_uv = vec2(uv.x + ((float(i)-(float(SAMPLE_COUNT)/2.0))/(910.0)), uv.y);
			vec3 yiq = rgb_to_yiq(texture(INPUT, temp_uv).rgb);
			samples[i] = yiq.x + i_carrier(temp_uv, yiq.y) + q_carrier(temp_uv, yiq.z);
			luma += samples[i] * bandpass_coefficients[i];
		}
		for(int i = 0; i < SAMPLE_COUNT; i++) {
			vec2 temp_uv = vec2(uv.x + ((float(i)-(float(SAMPLE_COUNT)/2.0))/(910.0)), uv.y);
			chroma_i += (samples[i]-luma)*i_carrier(temp_uv, 1.0)*i_coefficients[i];
			chroma_q += (samples[i]-luma)*q_carrier(temp_uv, 1.0)*q_coefficients[i];
		}
		return gamma(yiq_to_rgb(vec3(luma, chroma_i, chroma_q)));
}



vec2 visual_signal(vec2 uv) {
	int offset = 4;
	int lines = 525;
	int visible = 480;
	float ratio = float(lines)/float(visible);
	float difference = float(offset)/float(lines);
	return vec2(uv.x, (uv.y - difference)*ratio);
}

vec3 active_video_lines(vec2 uv) {
	int signal = int(uv.x * 63500.0);
	if(signal % 63500 <= 1500) {
		return ire_to_color(0.0);
	}
	else if (signal % 63500 <= 1500 + 4700) {
		return ire_to_color(-0.4);
	}
	else if (signal % 63500 <= 1500 + 4700 + 600) {
		return ire_to_color(0.0);
	}
	else if (signal % 63500 <= 1500 + 4700 + 600 + 2500) {
		return ire_to_color(i_carrier(uv, 0.2));
	}
	else if (signal % 63500 <= 1500 + 4700 + 600 + 2500 + 1600) {
		return ire_to_color(0.0);
	}
	else {
		return generate_video(true_uv(uv));
	}
}

vec3 blank_lines(float x) {
	int signal = int(x * 63500.0);
	if(signal % 63500 <= 1500) {
		return ire_to_color(0.0);
	}
	else if (signal % 63500 <= 1500 + 4700) {
		return ire_to_color(-0.4);
	}
	else {
		return ire_to_color(0.0);
	}
}

vec3 vertical_pulse(float x) {
	int signal = int(x * 63500.0);
	if(signal % 63500 <= 1500) {
		return ire_to_color(-0.4);
	}
	else if (signal % 63500 <= 1500 + 4700) {
		return ire_to_color(0.0);
	}
	else {
		return ire_to_color(-0.4);
	}
} 

vec3 display_video_frames(vec2 uv) {
	int signal = int(uv.y * 525.0);
	if (signal % 525 < 4) {
		return blank_lines(uv.x);
	}
	else if (signal % 525 < 4 + 480) {
		return active_video_lines(visual_signal(uv));
	}
	else if (signal % 525 < 4 + 480 + 6) {
		return blank_lines(uv.x);
	}
	else if (signal % 525 < 4 + 480 + 6 + 6) {
		return vertical_pulse(uv.x);
	}
	else {
		return blank_lines(uv.x);
	}
}

void fragment() {
	ALBEDO = generate_video(UV)*5.0;
}
