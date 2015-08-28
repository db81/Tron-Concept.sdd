function widget:GetInfo()
  return {
    name      = "Glowing Teamcolor",
    desc      = "Adds a subtle glow to teamcolored areas on units.",
    author    = "ikinz",
    date      = "June 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -3,
    enabled   = false
  }
end

local teamColors = {}
local filterTC, blurh, blurv
local teamColorUniform, screenWidthUniform, screenHeightUniform

local offscreen, offscreen2
local resChanged = true
local addBloom

function widget:Initialize()
    if (not gl.CreateShader) then
        Spring.Echo("Glowing Teamcolor: No shader support!")
        widgetHandler:RemoveWidget()
        return
    elseif (not gl.CreateFBO) then
        Spring.Echo("Glowing Teamcolor: No FBO support!")
        widgetHandler:RemoveWidget()
        return
    end
    
    local w, h = widgetHandler:GetViewSizes()

    filterTC = gl.CreateShader({
        fragment = [[
            uniform sampler2D tex;
            uniform vec3 teamColor;

            void main(void) {
                vec4 color = texture2D(tex, gl_TexCoord[0].st).a;
                gl_FragColor.rgb = teamColor * color.r * color.a;
                /*float depth = (2.0 * gl_FragCoord.z - gl_DepthRange.near - gl_DepthRange.far) /
                    (gl_DepthRange.far - gl_DepthRange.near);
                gl_FragColor.rgb = vec3((depth * 0.5) + 0.5);*/
                // Send the distance from camera in the alpha channel.
                // TODO: Check the math, I'm sure it's bullshit.
                gl_FragColor.a = 1.0 - gl_FragCoord.z / gl_FragCoord.w / 3000.0;
            }
        ]],
        uniform = {
            tex = 0,
            teamColor,
        },
    })
    if (filterTC == nil) then
        Spring.Echo("Glowing Teamcolor: Failed to compile filterTC shader:")
        Spring.Echo(gl.GetShaderLog())
        widgetHandler:RemoveWidget()
        return
    end
    teamColorUniform = gl.GetUniformLocation(filterTC, "teamColor")

    blurh = gl.CreateShader({
        fragment = [[
            uniform sampler2D tex;
            uniform float screenWidth;
            const vec2 k = vec2(0.6, 0.2);

            void main(void) {
                float s = gl_TexCoord[0].s;
                float t = gl_TexCoord[0].t;
                vec4 color = texture2D(tex, vec2(s, t));
                float p = 2.0 * color.a / screenWidth;
                color += k[1] * texture2D(tex, vec2(s - 2.0*p, t));
                color += k[0] * texture2D(tex, vec2(s - 1.0*p, t));
                color += k[0] * texture2D(tex, vec2(s + 1.0*p, t));
                color += k[1] * texture2D(tex, vec2(s + 2.0*p, t));
                gl_FragColor = 0.7 * color;
                //gl_FragColor = texture2D(tex, vec2(s,t));
                gl_FragColor.a = 1.0;

            }
        ]],
        uniform = {
            tex = 0,
            screenWidth = w,
        },
    })
    blurv = gl.CreateShader({
        fragment = [[
            uniform sampler2D tex;
            uniform sampler2D mask;
            uniform float screenHeight;
            const vec2 k = vec2(0.6, 0.2);

            void main(void) {
                float s = gl_TexCoord[0].s;
                float t = gl_TexCoord[0].t;
                vec4 src = texture2D(mask, vec2(s, t));
                float p = 2.0 * src.a / screenHeight;
                vec4 color = texture2D(tex, vec2(s, t));
                color += k[1] * texture2D(tex, vec2(s, t - 2.0*p));
                color += k[0] * texture2D(tex, vec2(s, t - 1.0*p));
                color += k[0] * texture2D(tex, vec2(s, t + 1.0*p));
                color += k[1] * texture2D(tex, vec2(s, t + 2.0*p));
                gl_FragColor = 0.7 * color;
                //gl_FragColor = texture2D(tex, vec2(s,t));
                gl_FragColor.a = 1.0;
            }
        ]],
        uniform = {
            screenHeight = h,
        },
        uniformInt = {
            tex = 0,
            mask = 1,
        },
    })
    if (blurh == nil or blurv == nil) then
        Spring.Echo("Glowing Teamcolor: Failed to compile blur shaders:")
        Spring.Echo(gl.GetShaderLog())
        widgetHandler:RemoveWidget()
        return
    end
    screenWidthUniform = gl.GetUniformLocation(blurh, "screenWidth")
    screenHeightUniform = gl.GetUniformLocation(blurv, "screenHeight")

    local teams = Spring.GetTeamList()
    for t = 1, #teams do
        teamColors[teams[t]] = {Spring.GetTeamColor(teams[t])}
    end

    self:ViewResize(w, h)
end

function widget:ViewResize(w, h)
    gl.DeleteTextureFBO(offscreen or 0)
    gl.DeleteTextureFBO(offscreen2 or 0)
    offscreen = gl.CreateTexture(w / 2, h / 2, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP,
        wrap_t = GL.CLAMP,
        fbo = true,
        fboDepth = true,
    })
    offscreen2 = gl.CreateTexture(w / 2, h / 2, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP,
        wrap_t = GL.CLAMP,
        fbo = true,
    })
    resChanged = true
end

function widget:Shutdown()
    -- TODO
end

function DrawTeamcolor()
    gl.MatrixMode(GL.PROJECTION); gl.LoadMatrix("projection")
    gl.MatrixMode(GL.MODELVIEW);  gl.LoadMatrix("view")

    gl.Blending("disable")
    gl.DepthMask(true)
    gl.DepthTest(GL.LEQUAL)
    gl.Clear(GL.COLOR_BUFFER_BIT, 0.0, 0.0, 0.0, 0.0)
    gl.Clear(GL.DEPTH_BUFFER_BIT, 1)
    gl.UseShader(filterTC)
    for t, c in pairs(teamColors) do
        local units = Spring.GetVisibleUnits(t, nil, false)
        gl.Uniform(teamColorUniform, c[1], c[2], c[3])
        for i = 1, #units do
            local def = Spring.GetUnitDefID(units[i])
            if def ~= nil and UnitDefs[def].model.type ~= "3do" then
                gl.Texture(0, "%" .. def .. ":0")
                gl.Unit(units[i], true)
            end
        end
    end
    gl.Texture(0, false)
    gl.UseShader(0)
    gl.DepthTest(false)
    gl.Blending("alpha")
end

function ApplyBlurh()
    gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
    gl.UseShader(blurh)
    if (resChanged) then
        local w, _ = widgetHandler:GetViewSizes()
        gl.Uniform(screenWidthUniform, w)
    end
    gl.TexRect(-1, 1, 1, -1)
end
function ApplyBlurv()
    -- Uncomment to only see the bloom overlay.
    --gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
    gl.UseShader(blurv)
    if (resChanged) then
        local _, h = widgetHandler:GetViewSizes()
        gl.Uniform(screenHeightUniform, h)
    end
    gl.TexRect(-1, 1, 1, -1)
end

function widget:DrawWorld()
    gl.RenderToTexture(offscreen, DrawTeamcolor)
    gl.Texture(0, offscreen)
    gl.RenderToTexture(offscreen2, ApplyBlurh)

    if (resChanged) then
        addBloom = gl.CreateList(function()
            gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
            gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity()

            gl.Texture(0, false)
            gl.UseShader(0)
            gl.Color(0.0, 0.0, 0.0, 0.2)
            gl.Rect(-1, 1, 1, -1)
            gl.Texture(0, offscreen2)
            gl.Texture(1, offscreen)
            gl.Blending("add")
            ApplyBlurv()
            gl.Blending("alpha")

            gl.MatrixMode(GL.PROJECTION); gl.PopMatrix()
            gl.MatrixMode(GL.MODELVIEW);  gl.PopMatrix()

            gl.Texture(0, false)
            gl.Texture(1, false)
            gl.UseShader(0)
        end)
    end
    gl.CallList(addBloom)

    if (resChanged) then resChanged = false end
end

function to_string(data, indent)
    local str = ""

    if(indent == nil) then
        indent = 0
    end

    -- Check the type
    if(type(data) == "string") then
        str = str .. (" "):rep(indent) .. data .. "\n"
    elseif(type(data) == "number") then
        str = str .. (" "):rep(indent) .. data .. "\n"
    elseif(type(data) == "boolean") then
        if(data == true) then
            str = str .. "true"
        else
            str = str .. "false"
        end
    elseif(type(data) == "table") then
        local i, v
        for i, v in pairs(data) do
            -- Check for a table in a table
            if(type(v) == "table") then
                str = str .. (" "):rep(indent) .. i .. ":\n"
                str = str .. to_string(v, indent + 2)
            else
                str = str .. (" "):rep(indent) .. i .. ": " ..
to_string(v, 0)
            end
        end
    elseif (data ==nil) then
		str=str..'nil'
	else
        print_debug(1, "Error: unknown data type: %s", type(data))
		str=str.. "Error: unknown data type:" .. type(data)
		Spring.Echo('X data type')
    end

    return str
end
