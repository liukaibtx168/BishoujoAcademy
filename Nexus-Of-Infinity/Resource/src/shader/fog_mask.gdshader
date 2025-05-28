shader_type canvas_item;

// 最多支持100个圆形区域和100个矩形区域
uniform vec3 circle_data[100]; // x, y, radius (每个圆的数据：x坐标，y坐标，半径)
uniform int circle_count = 0; // 实际圆形数量

uniform vec4 rect_data[100]; // x, y, width, height (每个矩形的数据：x坐标，y坐标，宽度，高度)
uniform int rect_count = 0; // 实际矩形数量

// 迷雾外观
uniform vec4 fog_color : source_color = vec4(0.15, 0.15, 0.15, 0.8); // 基础迷雾颜色
uniform sampler2D fog_texture_1; // 第一层迷雾纹理
uniform sampler2D fog_texture_2; // 第二层迷雾纹理

// 纹理尺寸控制
uniform vec2 texture_scale_1 = vec2(1.0, 1.0); // 第一层纹理缩放比例
uniform vec2 texture_scale_2 = vec2(1.4, 1.4); // 第二层纹理缩放比例

// 运动控制
uniform float speed_1 = 0.02; // 第一层纹理移动速度
uniform float speed_2 = 0.03; // 第二层纹理移动速度
uniform vec2 direction_1 = vec2(1.0, 0.5); // 第一层移动方向
uniform vec2 direction_2 = vec2(-0.7, 0.3); // 第二层移动方向

// 纹理混合
uniform float blend_ratio = 0.4; // 两个纹理的混合比例
uniform float texture_visibility = 0.6; // 纹理在最终颜色中的可见度

// 边缘渐变控制
uniform float edge_softness = 20.0; // 边缘渐变范围，值越大边缘越柔和

// 循环取模函数，确保纹理坐标在[0,1]范围内循环
vec2 wrap_coord(vec2 coord) {
    return fract(coord); // fract返回小数部分，实现循环效果
}

void fragment() {
	// Called once for every froxel that is touched by an axis-aligned bounding box
	// of the associated FogVolume. This means that froxels that just barely touch
	// a given FogVolume will still be used.

	// 检查当前像素是否在透明区域内
	float reveal_factor = 0.0; // 0.0表示完全不透明，1.0表示完全透明

	// 获取当前像素的屏幕坐标
	vec2 screen_coord = FRAGCOORD.xy;

	// 检查圆形区域
	for(int i = 0; i < circle_count; i++) {
		vec2 center = vec2(circle_data[i].x, circle_data[i].y);
		float radius = circle_data[i].z;

		// 计算当前像素到圆心的距离
		float dist = distance(screen_coord, center);

		// 如果在圆内或接近圆的边缘
		if(dist < radius + edge_softness) {
			// 计算边缘渐变因子
			float edge_factor = 1.0;
			if(dist > radius) {
				// 如果在边缘区域内，计算渐变
				edge_factor = 1.0 - (dist - radius) / edge_softness;
			}

			// 更新透明度因子，取最大值
			reveal_factor = max(reveal_factor, edge_factor);

			// 优化：如果已经达到完全透明，可以提前退出循环
			if(reveal_factor >= 0.99) {
				reveal_factor = 1.0;
				break;
			}
		}
	}

	// 检查矩形区域
	if(reveal_factor < 0.99) {
		for(int i = 0; i < rect_count; i++) {
			vec2 pos = vec2(rect_data[i].x, rect_data[i].y);
			vec2 size = vec2(rect_data[i].z, rect_data[i].w);

			// 计算像素到矩形各边的距离
			float dist_left = screen_coord.x - pos.x;
			float dist_right = pos.x + size.x - screen_coord.x;
			float dist_top = screen_coord.y - pos.y;
			float dist_bottom = pos.y + size.y - screen_coord.y;

			// 判断是否在矩形内部或边缘区域
			if(dist_left > -edge_softness && dist_right > -edge_softness &&
			   dist_top > -edge_softness && dist_bottom > -edge_softness) {

				float edge_factor = 1.0;

				// 如果在矩形外部但在边缘区域内
				if(dist_left < 0.0 || dist_right < 0.0 || dist_top < 0.0 || dist_bottom < 0.0) {
					// 计算到边缘的最短距离（为负值）
					float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
					// 计算渐变因子
					edge_factor = 1.0 + min_dist / edge_softness;
				}

				// 更新透明度因子，取最大值
				reveal_factor = max(reveal_factor, edge_factor);

				// 优化：如果已经达到完全透明，可以提前退出循环
				if(reveal_factor >= 0.99) {
					reveal_factor = 1.0;
					break;
				}
			}
		}
	}

	// 设置最终颜色
	if(reveal_factor > 0.0) {
		// 有部分或完全透明
		if(reveal_factor >= 1.0) {
			// 完全透明
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		} else {
			// 部分透明，混合迷雾效果
			// 计算迷雾颜色
			// 第一层纹理 - 使用循环纹理坐标
			vec2 tex_coord1 = UV * texture_scale_1;
			tex_coord1 += TIME * speed_1 * normalize(direction_1);
			tex_coord1 = wrap_coord(tex_coord1); // 确保坐标循环
			vec4 tex_color1 = texture(fog_texture_1, tex_coord1);

			// 第二层纹理 - 使用循环纹理坐标
			vec2 tex_coord2 = UV * texture_scale_2;
			tex_coord2 += TIME * speed_2 * normalize(direction_2);
			tex_coord2 = wrap_coord(tex_coord2); // 确保坐标循环
			vec4 tex_color2 = texture(fog_texture_2, tex_coord2);

			// 混合两个纹理
			vec4 combined_tex = mix(
				tex_color1,
				tex_color2,
				blend_ratio
			);

			// 混合迷雾颜色
			vec4 fog_result = vec4(
				mix(fog_color.rgb, combined_tex.rgb, texture_visibility),
				fog_color.a  // 保持原有的透明度
			);

			// 根据透明度因子应用渐变效果
			COLOR = vec4(fog_result.rgb, fog_result.a * (1.0 - reveal_factor));
		}
	} else {
		// 迷雾区域 - 使用两层不同的纹理混合

		// 第一层纹理 - 使用循环纹理坐标
		vec2 tex_coord1 = UV * texture_scale_1;
		tex_coord1 += TIME * speed_1 * normalize(direction_1);
		tex_coord1 = wrap_coord(tex_coord1); // 确保坐标循环
		vec4 tex_color1 = texture(fog_texture_1, tex_coord1);

		// 第二层纹理 - 使用循环纹理坐标
		vec2 tex_coord2 = UV * texture_scale_2;
		tex_coord2 += TIME * speed_2 * normalize(direction_2);
		tex_coord2 = wrap_coord(tex_coord2); // 确保坐标循环
		vec4 tex_color2 = texture(fog_texture_2, tex_coord2);

		// 混合两个纹理
		vec4 combined_tex = mix(
			tex_color1,
			tex_color2,
			blend_ratio
		);

		// 再与迷雾基础颜色混合
		COLOR = vec4(
			mix(fog_color.rgb, combined_tex.rgb, texture_visibility),
			fog_color.a  // 保持原有的透明度
		);
	}
}
