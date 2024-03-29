struct Camera {
    pos: vec4<f32>,
    view_proj: mat4x4<f32>,
};

@group(0) @binding(0)
var<uniform> camera: Camera;

struct SplatData {
    @location(0) center: vec3<f32>,
    @location(1) normal: vec3<f32>,
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) center: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) offset: vec3<f32>,
};

// The normal of the triangle generated by the following function
const K = vec3<f32>(0.0, 0.0, 1.0);
const SQRT3 = 1.732050807568877;
// The smallest possible triangle containing a unit circle
fn get_tri_offset(index: u32, n: vec3<f32>) -> vec3<f32> {
    var x: vec2<f32>;

    // Vertices of the smallest triangle inscribing the unit circle
    switch index {
        case 0u: { x = vec2<f32>(-SQRT3, -1.0); }
        case 1u: { x = vec2<f32>( SQRT3, -1.0); }
        case 2u: { x = vec2<f32>(   0.0,  2.0); }
        default: { }
    }

    // Rotate to align to normal
    // TODO: Simplify w/ substitution?
    // https://en.wikipedia.org/wiki/Rotation_matrix#Vector_to_vector_formulation

    // n * transpose(K)
    let nk = mat3x3<f32>(
        n.x * K.x, n.y * K.x, n.z * K.x,
        n.x * K.y, n.y * K.y, n.z * K.y,
        n.x * K.z, n.y * K.z, n.z * K.z,
    );
    let tmp = nk - transpose(nk);

    let I = mat3x3<f32>(
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    );
    let R = I + tmp + 1.0 / (1.0 + dot(K, n)) * tmp * tmp;

    return R * vec3<f32>(x, 0.0);
}

const SIZE = 0.0078125;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32, in: SplatData) -> VertexOutput {
    var out: VertexOutput;
    let n = normalize(in.normal);
    let offset = get_tri_offset(vertex_index, n);

    out.position = camera.view_proj * vec4<f32>(in.center + offset * SIZE, 1.0);
    out.center = in.center;
    out.normal = n;
    out.offset = offset;
    return out;
}

// TODO: Use uniform light buffer
const LIGHT_POS   = vec3<f32>(2.0, 2.0, 1.0);
const LIGHT_COLOR = vec3<f32>(1.0, 1.0, 1.0);
const LIGHT_POWER = 1.0;
const SPECULAR    = vec3<f32>(1.0, 1.0, 1.0);
const DIFFUSE     = vec3<f32>(0.5, 0.5, 0.5);
const AMBIENT     = vec3<f32>(0.1, 0.1, 0.1);
const SHINY       = 64.0;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    // Discard fragments that are not actually inside the circle to be rendered
    let d2 = dot(in.offset, in.offset);
    if (d2 > 1.0) {
        discard;
    }

    let world_position = in.center + in.offset * SIZE;

    // Blinn-Phong shading
    let ambient_color = LIGHT_COLOR * AMBIENT;

    let to_light = normalize(LIGHT_POS - world_position);
    let diffuse_color = LIGHT_COLOR * DIFFUSE * max(dot(in.normal, to_light), 0.0);

    let to_view = normalize(camera.pos.xyz - world_position);
    let specular_color = LIGHT_COLOR * SPECULAR * pow(max(dot(to_view, reflect(-to_light, in.normal)), 0.0), SHINY);

    return vec4<f32>(ambient_color + diffuse_color + specular_color, 1.0);
    // return vec4<f32>(1.0);
}

fn project_onto(point: vec3<f32>, planar: vec3<f32>, normal: vec3<f32>) -> vec3<f32> {
    return point - normal * dot(planar - point, normal);
}
