shader_type canvas_item;

// 最多支持10个圆形区域和10个矩形区域
uniform vec3 circle_data[10]; // x, y, radius (每个圆的数据：x坐标，y坐标，半径)
uniform int circle_count = 0; // 实际圆形数量

uniform vec4 rect_data[10]; // x, y, width, height (每个矩形的数据：x坐标，y坐标，宽度，高度)
uniform int rect_count = 0; // 实际矩形数量

uniform vec4 fog_color : source_color = vec4(0.1, 0.1, 0.1, 0.8); // 迷雾颜色
uniform sampler2D fog_texture; // 迷雾纹理
uniform bool use_fog_texture = true; // 是否使用迷雾纹理
uniform float fog_texture_scale = 1.0; // 纹理缩放
uniform float fog_movement_speed = 0.03; // 迷雾移动速度

void fragment() {
	// Called once for every froxel that is touched by an axis-aligned bounding box
	// of the associated FogVolume. This means that froxels that just barely touch
	// a given FogVolume will still be used.
	
	// 检查当前像素是否在任何一个圆形区域内
	bool in_revealed_area = false;
	
	// 获取当前像素的屏幕坐标
	vec2 screen_coord = FRAGCOORD.xy;
	
	// 检查圆形区域
	for(int i = 0; i < circle_count; i++) {
		vec2 center = vec2(circle_data[i].x, circle_data[i].y);
		float radius = circle_data[i].z;
		
		// 计算当前像素到圆心的距离
		float dist = distance(screen_coord, center);
		
		// 如果距离小于半径，则在区域内
		if(dist < radius) {
			// 添加一点边缘模糊效果
			float edge_blend = clamp((radius - dist) / 5.0, 0.0, 1.0);
			if(edge_blend > 0.1) {
				in_revealed_area = true;
				break;
			}
		}
	}
	
	// 检查矩形区域
	if(!in_revealed_area) {
		for(int i = 0; i < rect_count; i++) {
			vec2 pos = vec2(rect_data[i].x, rect_data[i].y);
			vec2 size = vec2(rect_data[i].z, rect_data[i].w);
			
			// 检查当前像素是否在矩形内
			if(screen_coord.x >= pos.x && screen_coord.x <= pos.x + size.x &&
			   screen_coord.y >= pos.y && screen_coord.y <= pos.y + size.y) {
				
				// 添加边缘模糊效果
				float edge_x = min(screen_coord.x - pos.x, pos.x + size.x - screen_coord.x);
				float edge_y = min(screen_coord.y - pos.y, pos.y + size.y - screen_coord.y);
				float edge_dist = min(edge_x, edge_y);
				float edge_blend = clamp(edge_dist / 5.0, 0.0, 1.0);
				
				if(edge_blend > 0.1) {
					in_revealed_area = true;
					break;
				}
			}
		}
	}
	
	// 设置最终颜色
	if(in_revealed_area) {
		// 在揭示区域内 - 完全透明
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// 在迷雾区域
		if(use_fog_texture) {
			// 第一层纹理 - 较大比例缓慢移动
			vec2 tex_coord1 = UV * fog_texture_scale;
			tex_coord1.x += TIME * fog_movement_speed * 0.1;
			tex_coord1.y += TIME * fog_movement_speed * 0.05;
			vec4 tex_color1 = texture(fog_texture, tex_coord1);
			
			// 第二层纹理 - 较小比例更快移动，创造深度感
			vec2 tex_coord2 = UV * (fog_texture_scale * 1.5);
			tex_coord2.x -= TIME * fog_movement_speed * 0.15;
			tex_coord2.y += TIME * fog_movement_speed * 0.07;
			vec4 tex_color2 = texture(fog_texture, tex_coord2);
			
			// 混合两层纹理
			vec4 combined_tex = mix(tex_color1, tex_color2, 0.4);
			
			// 最终与基础迷雾颜色混合
			COLOR = combined_tex * fog_color;
		} else {
			// 使用纯色迷雾
			COLOR = fog_color;
		}
	}
}
