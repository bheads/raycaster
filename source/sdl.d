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

/**
    TODO: create command list interface for this
*/
alias VK_LEFT = SDL_SCANCODE_LEFT;
alias VK_RIGHT = SDL_SCANCODE_RIGHT;
alias VK_UP = SDL_SCANCODE_UP;
alias VK_DOWN = SDL_SCANCODE_DOWN;



/* this sucks */
@trusted @nogc
void drawLine(ref scope Renderer renderer, int x1, int y1, int x2, int y2, ubyte r = 255, ubyte g = 255, ubyte b = 255) {
    SDL_SetRenderDrawColor(renderer.renderer, r, g, b, SDL_ALPHA_OPAQUE);
    SDL_RenderDrawLine(renderer.renderer, x1, y1, x2, y2);

}


struct Renderer {
    private SDL_Window*     window;
    private SDL_Renderer*   renderer;
    private SDL_Texture*    texture;

    private SDL_Event       event;
    ubyte*                  keys;

    void*                   pixels;
    int                     pitch;

    float delta; // fraction of 1 secound
    int fps = 0 ;
    private ulong last;
    private uint fCount = 0;
    private double fTime = 0;
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
            if(type == SDL_QUIT) return false; // fast exit!!
        }
        keys = SDL_GetKeyboardState(null);

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        SDL_RenderClear(renderer);
        sdlenforce(SDL_LockTexture(texture, null, &pixels, &pitch) == 0);
    }
    return true; // still running
}

@trusted 
void endFrame(ref scope Renderer r) {
    with (r) {
        SDL_UnlockTexture(texture);
        //sdlenforce(SDL_RenderCopy(renderer, texture, null, null) == 0);
        SDL_RenderPresent(renderer);
    }
}

//// todo: window flags...
@trusted
Renderer sdlInit(const int width = 800, const int height = 600) { 
    auto renderer = Renderer();
    sdlenforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) == 0);
    sdlenforce(SDL_CreateWindowAndRenderer(width, height, SDL_WINDOW_ALLOW_HIGHDPI, &renderer.window, &renderer.renderer) == 0);

    renderer.texture =  sdlenforce(SDL_CreateTexture(renderer.renderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STREAMING, 800, 450));

    renderer.last = SDL_GetPerformanceCounter();

    return renderer;
}

@trusted
void sdlQuit(ref scope Renderer renderer) {

    // clean up window bits
    SDL_DestroyTexture(renderer.texture);
    SDL_DestroyRenderer(renderer.renderer);
    SDL_DestroyWindow(renderer.window);

    SDL_Quit();
}



private:


//// Import the SDL DLL on startup.. (may need to move this into the init method ? )
shared static this() {
    // Load the SDL 2 library.
    DerelictSDL2.load();
}

pragma(inline, true)
T sdlenforce(T) (T value, string file = __FILE__, size_t line = __LINE__) {
    import std.exception : enforce;
    import std.format : format;
    import std.conv : to;

    return enforce(value, format("SDL Error %s", SDL_GetError().to!string), file, line);
}



