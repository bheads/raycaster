module raycaster.main;

import std.stdio : writeln;
import core.thread;

import raycaster.sdl;
import raycaster.game;

int main()
{
	try {
		auto renderer = init(1280, 720);
		scope(exit) quit(renderer);
		
		auto world = World();
		world.initLevel("map1.json");

		// Main Loop
		//auto t = new Thread({frame(renderer, world);}).start();
		for(bool running = true; running; running = renderer.startFrame) {
			frame(renderer, world); // todo: frame limiter, or vsync?		
			renderer.endFrame();
		}
		renderer.running = false;

		return 0;
	} catch (Exception e) {		
		writeln("Unhandled Exception: ", e);
	} catch (Error e) {
		writeln("Unhandled Exception: ", e);
	}
	return -1;
}



Renderer init(const int width = 800, const int height = 600) {
	return sdlInit(width, height);
}

void quit(Renderer r) {
	sdlQuit(r);
}

