module raycaster.sdl;
/**
 * Hide the details of the SDL implementation in here.
 * TODO: Make this an interface?
 */
private:
import std.string : toStringz;
import std.format : format;


import derelict.sdl2.sdl;


public:
import core.sync.barrier;

import imageformats;

/**
    TODO: create command list interface for this
*/
alias VK_LEFT = SDL_SCANCODE_LEFT;
alias VK_RIGHT = SDL_SCANCODE_RIGHT;
alias VK_UP = SDL_SCANCODE_UP;
alias VK_DOWN = SDL_SCANCODE_DOWN;



union Color {
    struct {
        ubyte r;
        ubyte g;
        ubyte b;
        ubyte a;
    }
    uint full;
}

struct Renderer {
    private SDL_Window*     window;
    private int             w;
    private int             h;

    private SDL_Renderer*   rend;
    private SDL_Texture*    texture;

    private SDL_Event       event;
    ubyte*                  keys;

    float delta; // fraction of 1 secound
    int fps = 0 ;
    private ulong last;
    private uint fCount = 0;
    private double fTime = 0;

    Barrier                 barrier;

    IFImage[char]           textures;

    // Need two buffers in the heap
    //Color[textureWidth][textureHeight]   buffer;
    Color*[2]               buffers;
    int                     bindex = 0;

    bool                    running = true;
}

@trusted //@nogc
bool startFrame(ref scope Renderer r) {    
    with (r) {
        // compute frame time
        auto now = SDL_GetPerformanceCounter();
        delta = (cast(double)((now - last)*1000) / SDL_GetPerformanceFrequency()) / 1000.0f;
        last = now;
        // compute fps
        fCount += 1;
        fTime += delta;
        if (fTime >= 1.0) {
            fTime -= 1.0;
            fps = fCount;
            fCount = 0;
            SDL_SetWindowTitle(window, format("RayCaster FPS: %s  DELTA: %s", fps, delta).toStringz);
        }


        // Process events
        while (SDL_PollEvent(&event)) with(event) {
            if(type == SDL_QUIT) {
                r.running = false;
                barrier.wait();
                return false; // fast exit!!
            }
        }
        keys = SDL_GetKeyboardState(null);

        SDL_SetRenderDrawColor(rend, 0, 0, 255, 0);
        SDL_RenderClear(rend);
//        sdlenforce(SDL_LockTexture(texture, null, &pixels, &pitch) == 0);
        //for(int i = 0; i < pitch * textureHeight; i++barrier) (cast(ubyte*) pixels)[i] = cast(ubyte)128;
    }
    //r.barrier.wait();
    return true; // still running
}

@trusted 
void endFrame(ref scope Renderer r) {
    with (r) {
  //      SDL_UnlockTexture(texture);
        barrier.wait();
        SDL_UpdateTexture(texture, null, buffers[bindex], textureWidth * Color.sizeof);
        bindex = (bindex + 1) % 2;

        // Note: sdl makes the quad then rotates it...
        auto destrect = SDL_Rect(0, h, h, w);
        auto rotrect = SDL_Point(0, 0);
        sdlenforce(SDL_RenderCopyEx(rend, texture, null, &destrect, -90.0, &rotrect, SDL_FLIP_NONE) == 0);
        //sdlenforce(SDL_RenderCopy(renderer, texture, &srcrect, &destrect) == 0);//, -90.0, null, SDL_FLIP_NONE) == 0);
        SDL_RenderPresent(rend);
        
    }
}

const int textureWidth = 450;//0;//450;
const int textureHeight = 800;//0;//800;

import std.stdio;

//// todo: window flags...
@trusted
Renderer sdlInit(const int width = 800, const int height = 600) { 
    auto renderer = Renderer();
    
    with (renderer) {    
        sdlenforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) == 0);
        sdlenforce(window = SDL_CreateWindow("", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_ALLOW_HIGHDPI));
        sdlenforce(rend = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC));
        //sdlenforce(SDL_CreateWindowAndRenderer(width, height, SDL_WINDOW_ALLOW_HIGHDPI, &window, &rend) == 0);
        w = width;
        h = height;
        texture =  sdlenforce(SDL_CreateTexture(rend, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STREAMING, textureWidth, textureHeight));

        last = SDL_GetPerformanceCounter();

        textures['s'] = read_image("pics/stone1.png", ColFmt.RGBA);
        textures['f'] = read_image("pics/floor.png", ColFmt.RGBA);
        textures['c'] = read_image("pics/ceiling.png", ColFmt.RGBA);

        barrier = new Barrier(2);

        buffers[0] = (new Color[textureWidth * textureHeight]).ptr;
        buffers[1] = (new Color[textureWidth * textureHeight]).ptr;
    }

    return renderer;
}

@trusted
void sdlQuit(ref scope Renderer renderer) {

    // clean up window bits
    SDL_DestroyTexture(renderer.texture);
    SDL_DestroyRenderer(renderer.rend);
    SDL_DestroyWindow(renderer.window);

    SDL_Quit();
}



private:


//// Import the SDL DLL on startup.. (may need to move this into the init method ? )
shared static this() {
    // Load the SDL 2 library.
    DerelictSDL2.load();
}

//pragma(inline, true)
T sdlenforce(T) (T value, string file = __FILE__, size_t line = __LINE__) {
    import std.exception : enforce;
    import std.format : format;
    import std.conv : to;

    return enforce(value, format("SDL Error %s", SDL_GetError().to!string), file, line);
}



