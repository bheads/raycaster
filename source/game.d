module raycaster.game;


import raycaster.sdl;

import gl3n.linalg;
import gl3n.math;
import gl3n.interpolate;

// todo: mempool?
debug import std.stdio;


//// GameWorld
struct World {
    vec2i screen = vec2i(textureHeight, textureWidth); // screen dimensions
    int[][] map;
    vec2 position = vec2(22f, 12f);
    vec2 direction = vec2(-1f, 0f);
    vec2 plane = vec2(0f, 0.66f);

    this(this) @disable;
}


const moveSpeed = 6.0;
const rotationSpeed = 2.0*PI/3.0;

@system @nogc
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

            int lineHeight = cast(int)((screen.y / perpWallDist) * 1);
            int drawStart = clamp(-lineHeight / 2 + screen.y / 2, 0, screen.y - 1);
            int drawEnd = clamp(lineHeight / 2 + screen.y / 2, 0, screen.y - 1);
            
            // todo: lighting sucks... Add more point lights into the mix
            auto ambiant = vec3(0.05f); // ambiant light;
            float dist = 1+perpWallDist^^2;
            float intensity = 3f;
            // //light += slerp(vec3(1f), vec3(0f), smoothstep(0, intensity, perpWallDist));
            // //light += vec3(1f) * intensity / (1+dist);
            // light += slerp(vec3(0f), vec3(1f), max(0, intensity / (1+ dist)));
            
            //texturing calculations
            int texNum = clamp(map[mappos.y][mappos.x]-1, 0, 5); //1 subtracted from it so that texture 0 can be used!
            auto tex = &r.walls[texNum];

            //calculate value of wallX
            double wallX; //where exactly the wall was hit
            if (side == 0) wallX = position.y + perpWallDist * ray.y;
            else           wallX = position.x + perpWallDist * ray.x;
            wallX -= (floor(wallX));

            //x coordinate on the texture
            int texX = cast(int)(wallX * tex.w);
            if(side == 0 && ray.x > 0) texX = tex.w - texX - 1;
            if(side == 1 && ray.y < 0) texX = tex.w - texX - 1;

           // auto light = ambiant + slerp(vec3(1f), vec3(0f), smoothstep(0, intensity, perpWallDist));
            auto light = ambiant + slerp(vec3(0f), vec3(1f), max(0, intensity / (1+ dist)));
            uint drawcolor;
            foreach(int y; drawStart..drawEnd) {
                // Compute color at this position
                    int d = y * 256 - screen.y * 128 + lineHeight * 128;  //256 and 128 factors to avoid floats
                    int texY = ((d * tex.h) / lineHeight) / 256;

                    texX = clamp(texX, 0, tex.w-1);
                    texY = clamp(texY, 0, tex.h-1);

                    Color c = Color(255, tex.pixels[(tex.w * 4 * texY) + (texX * 4) + 2], tex.pixels[(tex.w * 4 * texY) + (texX * 4) + 1], tex.pixels[(tex.w * 4 * texY) + (texX * 4) + 0]);

                    c.r = cast(ubyte)(c.r * light.x);
                    c.g = cast(ubyte)(c.g * light.y);
                    c.b = cast(ubyte)(c.b * light.z);

                    drawcolor = c.full;// cast(uint*)(tex.pixels)[1];//[tex.w * texY + texX];
                    (cast(int*)r.pixels)[(x * (r.pitch/4)) + y] = drawcolor;
            }

            // Draw the floors and ceiling

             //FLOOR CASTING
            vec2 floor;
            
            //4 different wall directions possible
            if(side == 0 && ray.x > 0) {
                floor.x = mappos.x;
                floor.y = mappos.y + wallX;
            } else if(side == 0 && ray.x < 0) {
                floor.x = mappos.x + 1.0;
                floor.y = mappos.y + wallX;
            } else if(side == 1 && ray.y > 0) {
                floor.x = mappos.x + wallX;
                floor.y = mappos.y;
            } else {
                floor.x = mappos.x + wallX;
                floor.y = mappos.y + 1.0;
            }

            double distWall, distPlayer, currentDist;

            distWall = perpWallDist;
            distPlayer = 0.0;

            if (drawEnd < 0) drawEnd = screen.y; //becomes < 0 when the integer overflows

            //draw the floor from drawEnd to the bottom of the screen
            auto ftex = &r.walls[7];
            auto ctex = &r.walls[8];
            for(int y = drawStart; y >= 0; y--) {
                currentDist = screen.y / (screen.y - 2.0 * y); //you could make a small lookup table for this instead
                dist = 1+currentDist^^2;
                light = ambiant + slerp(vec3(0f), vec3(1f), max(0, intensity / (1+ dist)));
            
                double weight = (currentDist - distPlayer) / (distWall - distPlayer);

                auto tile = weight * floor + (1.0 - weight) * position;
                // double currentFloorX = weight * floorXWall + (1.0 - weight) * position.x;
                // double currentFloorY = weight * floorYWall + (1.0 - weight) * posY;

                int floorTexX, floorTexY;
                floorTexX = cast(int)clamp((tile.x * ftex.w) % ftex.w, 0, ftex.w-1);
                floorTexY = cast(int)clamp((tile.y * ftex.h) % ftex.h, 0, ftex.h-1);

                Color c = Color(255, ftex.pixels[(ftex.w * 4 * floorTexY) + (floorTexX * 4) + 2], ftex.pixels[(ftex.w * 4 * floorTexY) + (floorTexX * 4) + 1], ftex.pixels[(ftex.w * 4 * floorTexY) + (floorTexX * 4) + 0]);

                c.r = cast(ubyte)(c.r * light.x);
                c.g = cast(ubyte)(c.g * light.y);
                c.b = cast(ubyte)(c.b * light.z);

                drawcolor = c.full;// cast(uint*)(tex.pixels)[1];//[tex.w * texY + texX];
                (cast(int*)r.pixels)[(x * (r.pitch/4)) + y] = drawcolor;// & 8355711;

                //ceiling (symmetrical!)
                floorTexX = cast(int)clamp((tile.x * ctex.w) % ctex.w, 0, ctex.w-1);
                floorTexY = cast(int)clamp((tile.y * ctex.h) % ctex.h, 0, ctex.h-1);

                c = Color(255, ctex.pixels[(ctex.w * 4 * floorTexY) + (floorTexX * 4) + 2], ctex.pixels[(ctex.w * 4 * floorTexY) + (floorTexX * 4) + 1], ctex.pixels[(ctex.w * 4 * floorTexY) + (floorTexX * 4) + 0]);

                c.r = cast(ubyte)(c.r * light.x);
                c.g = cast(ubyte)(c.g * light.y);
                c.b = cast(ubyte)(c.b * light.z);

                drawcolor = c.full;// cast(uint*)(tex.pixels)[1];//[tex.w * texY + texX];
                (cast(int*)r.pixels)[(x * (r.pitch/4)) + (screen.y - y)] = drawcolor;
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
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1],
        [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1],
        [1,0,0,0,0,0,2,2,2,2,2,0,0,0,0,3,0,3,0,3,0,0,0,1,1],
        [1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1,1],
        [1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,3,0,0,0,3,0,0,0,1,1],
        [1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1,1],
        [1,0,0,0,0,0,2,2,0,2,2,0,0,0,0,3,0,3,0,3,0,0,0,1,1],
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
