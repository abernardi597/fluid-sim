use fluid_sim::run;

#[cfg(not(target_arch="wasm32"))]
fn main() {
    env_logger::init();
    pollster::block_on(run(winit::window::WindowBuilder::new()));
}
