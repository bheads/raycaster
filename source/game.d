module raycaster.game;
import std.range : iota;
import std.parallelism;

import raycaster.sdl;

import gl3n.linalg;
import gl3n.math;
import gl3n.interpolate;

// todo: mempool?
debug import std.stdio;

import std.ascii : toLower;

//// GameWorld
struct World {
    vec2i screen = vec2i(textureHeight, textureWidth); // screen dimensions
    string[] map;
    vec2 position = vec2(1.5f, 1.5f);
    vec2 direction = vec2(0f, 1f);
    vec2 plane = vec2(0.76f, 0f);

    this(this) @disable;
}

pragma(inline, true)
uint vec3ToInt(scope ref vec3 v) {
    // little endien
    return (cast(int)v.x << 24) + (cast(int)v.y << 16) + (cast(int)v.z << 8) + 255 ; 
    //return (255<<24) + (0 << 16) + (0 << 8) + 255;//128;
}


//pragma(inline, true)
auto ref vclamp(ref vec3 v, float min = 0f, float max = 1f) {
    v.x = clamp(v.x, min, max);
    v.y = clamp(v.y, min, max);
    v.z = clamp(v.z, min, max);
    return v;
}

pragma(inline, true)
vec3 mult(vec3 a, vec3 b) {
    vec3 r;
    r.x = a.x * b.x;
    r.y = a.y * b.y;
    r.z = a.z * b.z;

    return r; 
}

const moveSpeed = 6.0;
const rotationSpeed = 2.0*PI/3.0;

@system //@nogc
void frame(ref scope Renderer r, ref scope World w) {
    //while(r.running)
    with (w) { 
       // r.barrier.wait();  
        // input
        const float delta = r.delta;
        //if (delta >= 0) continue;

        //// TODO: Collision
        if (r.keys !is null && r.keys[VK_UP]) {
            auto newpos = position + direction * moveSpeed * delta;
            if (map[cast(int)newpos.y][cast(int)newpos.x] >= 'a') position = newpos;
        }
        if (r.keys !is null && r.keys[VK_DOWN]) {
            auto newpos = position - direction * moveSpeed * delta;
            if (map[cast(int)newpos.y][cast(int)newpos.x] >= 'a') position = newpos;
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

        // Render
        // foreach col on the screen
        foreach(int x; parallel(iota(0, screen.x))) {
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

//            int t = 0;
            while(hit == 0) {
  //              t++;
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

                if (mappos.x < 0 || mappos.y < 0 || mappos.y >= map.length || mappos.x >= map[mappos.y].length) break;
                // check for a hit!
                if (map[mappos.y][mappos.x] <= 'Z') hit = 1;
            }

            //if (hit == 0) continue; // skip misses
            if (side == 0) {
                perpWallDist = (mappos.x - position.x + (1 - step.x) / 2) / ray.x;
            } else {
                perpWallDist = (mappos.y - position.y + (1 - step.y) / 2) / ray.y;
            }

            int lineHeight = cast(int)((screen.y / perpWallDist) * 1);
            if (hit == 0) lineHeight = 0;
            int drawStart = clamp(-lineHeight / 2 + screen.y / 2, 0, screen.y);
            int drawEnd = clamp(lineHeight / 2 + screen.y / 2, 0, screen.y);
            
            // todo: lighting sucks... Add more point lights into the mix
            auto ambiant = vec3(0.1f); // ambiant light;
            float dist = 1+perpWallDist^^2;
            float intensity = 2f;
            // //light += slerp(vec3(1f), vec3(0f), smoothstep(0, intensity, perpWallDist));
            // //light += vec3(1f) * intensity / (1+dist);
            // light += slerp(vec3(0f), vec3(1f), max(0, intensity / (1+ dist)));
            
            //texturing calculations
            auto tex = &r.textures[map[mappos.y][mappos.x].toLower];

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
            vec3 light = (ambiant + lerp(vec3(0f), vec3(1f), smoothstep(0f, 1f, (intensity / (1+ dist)))));
            auto pixels = cast(Color*)tex.pixels.ptr;

            foreach(int y; drawStart..drawEnd) {
                // Compute color at this position
                    int d = y * 256 - screen.y * 128 + lineHeight * 128;  //256 and 128 factors to avoid floats
                    int texY = ((d * tex.h) / lineHeight) / 256;

                    texX = clamp(texX, 0, tex.w-1);
                    texY = clamp(texY, 0, tex.h-1);

                    auto c = pixels[(tex.w * texY) + texX];
                    vec3 color = vec3(c.r/255f, c.g/255f, c.b/255f).mult(vec3(light));// light;
                    color = vclamp(color) * 255f;
                    r.buffers[r.bufferIndex][x][y].full = vec3ToInt(color);
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

            auto ctex = &r.textures['c'];
            auto cpixels = cast(Color*)ctex.pixels.ptr;
            int texY;

            //draw the floor from drawEnd to the bottom of the screen
            for(int y = drawStart - 1; y >= 0; y--) {
                currentDist = screen.y / (screen.y - 2.0 * y); //you could make a small lookup table for this instead
                dist = 1+currentDist^^2;
                light = ambiant + slerp(vec3(0f), vec3(1f), smoothstep(0f, 1f, intensity / (1+ dist)));
               
                double weight = (currentDist - distPlayer) / (distWall - distPlayer);
                auto tile = weight * floor + (1.0 - weight) * position;
                if (tile.x < 0 || tile.y < 0 || tile.y >= map.length || tile.x >= map[cast(int)tile.y].length) continue;

                auto findex = map[cast(int)tile.y][cast(int)tile.x];
                auto ftex = findex in r.textures;
                if (ftex is null) continue;
                auto fpixels = cast(Color*)ftex.pixels.ptr;
            
                texX = cast(int)clamp((tile.x * ftex.w) % ftex.w, 0, ftex.w-1);
                texY = cast(int)clamp((tile.y * ftex.h) % ftex.h, 0, ftex.h-1);

                auto c = fpixels[(ftex.w * texY) + texX];
                vec3 color = vec3(c.r/255f, c.g/255f, c.b/255f).mult(vec3(light));// light;
                color = vclamp(color) * 255f;
                r.buffers[r.bufferIndex][x][y].full = vec3ToInt(color);
                
                //ceiling (symmetrical!)
                texX = cast(int)clamp((tile.x * ctex.w) % ctex.w, 0, ctex.w-1);
                texY = cast(int)clamp((tile.y * ctex.h) % ctex.h, 0, ctex.h-1);

                c = cpixels[(ctex.w * texY) + texX];
                color = vec3(c.r/255f, c.g/255f, c.b/255f).mult(vec3(light));// light;
                color = vclamp(color) * 255f;
                r.buffers[r.bufferIndex][x][screen.y - 1- y].full = vec3ToInt(color);

            } // y
        } // x
        //r.barrier.wait();
    }// with
}


void initLevel(ref scope World w, scope string map) {
    import std.conv : to;
    w.map = 
    [
        "SSSSSSSSSSSSSSSS",
        "ScssssssssssssfS",
        "SsSSSSSSSSSSSSsSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS",
        "SfFffffffffffSffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SsSfSSSfSSSSfSfSffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "CcffSfffSffSfffSffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SSSSSfSSSffSSSSSffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SffffffffffSffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfSSSSSSSSfSffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfSfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffS",
        "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
    ];
}
