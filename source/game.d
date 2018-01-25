module raycaster.game;


import raycaster.sdl;

import gl3n.linalg;
import gl3n.math;
import gl3n.interpolate;

// todo: mempool?
debug import std.stdio;


//// GameWorld
struct World {
    vec2i screen = vec2i(800, 450); // screen dimensions
    int[][] map;
    vec2 position = vec2(22f, 12f);
    vec2 direction = vec2(-1f, 0f);
    vec2 plane = vec2(0f, 0.66f);

    this(this) @disable;
}


const moveSpeed = 6.0;
const rotationSpeed = 2.0*PI/3.0;

@system //@nogc
void frame(const float delta, ref scope Renderer r, ref scope World w) {
    with (w) {   
        // input

        //// TODO: Collision
        if (r.keys !is null && r.keys[VK_UP]) {
            auto newpos = position + direction * moveSpeed * delta;
            if (map[cast(int)newpos.y][cast(int)newpos.x] == 0) position = newpos;
        }
        if (r.keys !is null && r.keys[VK_DOWN]) {
            auto newpos = position - direction * moveSpeed * delta;
            if (map[cast(int)newpos.y][cast(int)newpos.x] == 0) position = newpos;
        }        
        if (r.keys !is null && r.keys[VK_RIGHT]) {
            auto angle = rotationSpeed * delta;
            auto rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

            direction = direction * rot;
            plane = plane * rot;
        }
        if (r.keys !is null && r.keys[VK_LEFT]) {
            auto angle = -rotationSpeed * delta;
            auto rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

            direction = direction * rot;
            plane = plane * rot;
        }

        if (r.pixels is null) return;
        

        // Render
        // foreach col on the screen
        foreach(int x; 0..screen.x) {
            double cameraX = 2.0 * x / screen.x - 1.0;
            auto ray = vec2d(direction.x + plane.x * cameraX, direction.y + plane.y * cameraX);
            auto mappos = vec2i(cast(int)position.x, cast(int)position.y);
            vec2d sideDist;
            vec2d deltaDist = vec2d(abs(1/ray.x), abs(1/ray.y)); // is this correct?
            double perpWallDist = 0.0;
            vec2i step = vec2i(1, 1);
            int hit = 0;
            int side = 0;

            if (ray.x < 0) {
                step.x = -1;
                sideDist.x = (position.x - mappos.x) * deltaDist.x;
            } else {
                sideDist.x = (mappos.x + 1.0 - position.x) * deltaDist.x;
            }
            if (ray.y < 0) {
                step.y = -1;
                sideDist.y = (position.y - mappos.y) * deltaDist.y;
            } else {
                sideDist.y = (mappos.y + 1.0 - position.y) * deltaDist.y;
            }

            while(hit == 0) {
                // find the shorted dist
                if (sideDist.x < sideDist.y) {
                    sideDist.x += deltaDist.x;
                    mappos.x += step.x;
                    side = 0;
                } else {
                    sideDist.y += deltaDist.y;
                    mappos.y += step.y;
                    side = 1;
                }

                if (mappos.x < 0 || mappos.y < 0 || mappos.x >= map[0].length || mappos.y >= map.length) break;
                // check for a hit!
                if (map[mappos.y][mappos.x] > 0) hit = 1;
            }

            if (hit == 0) continue; // skip misses
            if (side == 0) {
                perpWallDist = (mappos.x - position.x + (1 - step.x) / 2) / ray.x;
            } else {
                perpWallDist = (mappos.y - position.y + (1 - step.y) / 2) / ray.y;
            }

            int lineHeight = cast(int)(screen.y / perpWallDist);
            int drawStart = clamp(-lineHeight / 2 + screen.y / 2, 0, screen.y - 1);
            int drawEnd = clamp(lineHeight / 2 + screen.y / 2, 0, screen.y - 1);
            
            auto color = vec3(1.0f);

            switch(map[mappos.y][mappos.x]) {
                case 1:
                    color = vec3(1.0f, 0.002f, 0.002f);
                    break;
                case 2:
                    color = vec3(0.02f, 1.0f, 0.02f);
                    break;
                case 3:
                    color = vec3(0.2f, 1.0f, 1.0f);
                    break;
                case 4:
                    color = vec3(1.0f, 1.0f, 0.02f);
                    break;
                case 5:
                    color = vec3(1.0f, 00.02f, 1.0f);
                    break;
                default:
            }

            if (side == 1) {
                //color /= 2.0f;
            }

            // todo: lighting sucks... Add more point lights into the mix
            auto light = vec3(0.02f); // ambiant light;
            float dist = 1+perpWallDist^^2;
            float intensity = 3f;
            //light += slerp(vec3(1f), vec3(0f), smoothstep(0, intensity, perpWallDist));
            //light += vec3(1f) * intensity / (1+dist);
            light += slerp(vec3(0f), vec3(1f), max(0, intensity / (1+ dist)));
            
            color.r *= light.r;
            color.g *= light.g;
            color.b *= light.b;
           
            color.r = clamp(color.r, 0.0f, 1.0f);
            color.g = clamp(color.g, 0.0f, 1.0f);
            color.b = clamp(color.b, 0.0f, 1.0f);
            color *= 255.0f;

            // New method, drawing to the texture memory
            // This uses little endien (may need to detect for other hardware...)
            auto c = Color(255, cast(ubyte) (color.b), cast(ubyte) (color.g), cast(ubyte) (color.r));
            foreach(int y; 0..screen.y) {
                if (y >= drawStart && y <= drawEnd){
                    (cast(int*)r.pixels)[(x * (r.pitch/4)) + y] = c.full;
                } else {
                    (cast(int*)r.pixels)[(x * (r.pitch/4)) + y] = 0x0;// c.full;
                }
            }
        }
    }
}


union Color {
    struct {
        ubyte a;
        ubyte b;
        ubyte g;
        ubyte r;
    }
    int full;
}

void initMap(ref scope World w) {
    w.map = 
    [
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,2,2,2,2,2,0,0,0,0,3,0,3,0,3,0,0,0,1],
        [1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,3,0,0,0,3,0,0,0,1],
        [1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,2,2,0,2,2,0,0,0,0,3,0,3,0,3,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,0,4,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,0,0,0,0,5,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,0,4,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,0,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    ];
}
