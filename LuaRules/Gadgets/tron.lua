function gadget:GetInfo()
  return {
    name      = "Tron Gadget",
    desc      = "An exercise in neonity.",
    author    = "ikinz",
    date      = "June 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -3,
    enabled   = true
  }
end

if gadgetHandler:IsSyncedCode() then

else

local unitsToDraw = {}

local groundShader

function gadget:Initialize()
    if (not gl.CreateShader) then
        Spring.Echo("Tron: No shader support!")
        gadgetHandler:RemoveGadget()
        return
    elseif (not gl.CreateFBO) then
        Spring.Echo("Tron: No FBO support!")
        gadgetHandler:RemoveGadget()
        return
    end

    local w, h = gadgetHandler:GetViewSizes()

    local mapPwr2Width = nextPwr2(Game.mapSizeX / Game.squareSize) * Game.squareSize
    local mapPwr2Height = nextPwr2(Game.mapSizeZ / Game.squareSize) * Game.squareSize
    groundShader = gl.CreateShader({
        vertex = [[
            varying vec3 pos;
            varying float cameraDist;

            void main(void) {
                gl_Position = gl_ModelViewMatrix * gl_Vertex;
                cameraDist = length(gl_Position.xyz);
                gl_Position = gl_ProjectionMatrix * gl_Position;
                pos = gl_Vertex;
            }
        ]],
        fragment = [[
            uniform vec2 mapSize;
            uniform sampler2D infoTex;
            uniform vec2 infoTexGen;

            varying vec3 pos;
            varying float cameraDist;

            const vec3 borderColor = vec3(0.2, 0.4, 0.8);

            float borders(float x) {
                return clamp(sign(0.01 - fract(x * 100)), 0, 1.0);
            }

            void main(void) {
                vec2 mapPos = pos.xz / mapSize;
                // TODO: see if gl_Normal contains anything useful.
                gl_FragColor.rgb = mix(vec3(0), borderColor,
                    clamp(borders(mapPos.x) + borders(mapPos.y), 0, 1.0));
                //gl_FragColor.b = cameraDist / 10000;
                gl_FragColor.rgb += texture2D(infoTex, pos.xz / infoTexGen);
                gl_FragColor.rgb -= vec3(0.5);
                gl_FragColor.a = 1.0;
            }
        ]],
        uniform = {
            mapSize = { Game.mapSizeX, Game.mapSizeZ },
            infoTex = 0,
            infoTexGen = { mapPwr2Width, mapPwr2Height },
        },
    })
    if (groundShader == nil) then
        Spring.Echo("Tron: Failed to compile ground shader:")
        Spring.Echo(gl.GetShaderLog())
        gadgetHandler:RemoveGadget()
        return
    end

    self:ViewResize(w, h)
end

function gadget:ViewResize(w, h)
end

function gadget:DrawWorldPreUnit()
    gl.UseShader(groundShader);
    gl.Texture(0, "$info")
    gl.DrawGroundQuad(0, 0, Game.mapSizeX, Game.mapSizeZ)
    gl.UseShader(0);
    gl.Texture(0, false)
    gl.DepthMask(true)
    gl.DepthTest(GL.LEQUAL)
    gl.Color(0.6, 0.7, 0.12, 0.7)
    for unitID,_ in pairs(unitsToDraw) do
        -- I have to set UnitLuaDraw to true to be able to override unit
        -- rendering, but to actually draw with gl.Unit I have to set it to
        -- false. The hoops I have to jump through...
        Spring.UnitRendering.SetUnitLuaDraw(unitID, false)
        gl.Unit(unitID, true)
        Spring.UnitRendering.SetUnitLuaDraw(unitID, true)
        --[[local def = Spring.GetUnitDefID(unitID)
        if def ~= nil and UnitDefs[def].model.type ~= "3do" then
            gl.Texture(0, "%" .. def .. ":0")
            gl.Unit(unitID, true)
        end]]--
        gl.PushMatrix()
        gl.UnitMultMatrix(unitID)
        gl.Rect(-2, 2, 2, -2)
        gl.PopMatrix()
        unitsToDraw[unitID] = nil
    end
    gl.DepthTest(false)
    gl.DepthMask(false)
end

function gadget:Shutdown()
    -- TODO
end

function gadget:UnitCreated(unitID)
    Spring.UnitRendering.SetUnitLuaDraw(unitID, true)
end

function gadget:UnitDestroyed(unitID)
    Spring.UnitRendering.SetUnitLuaDraw(unitID, false)
end

function gadget:DrawUnit(unitID, drawMode)
    -- TODO: Perhaps a better build progress FX? Because I have unlimited stamina and free time.
    local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
    if drawMode == 1 and buildProgress > 0.999 and not Spring.GetUnitIsStunned(unitID) then
        unitsToDraw[unitID] = true
        return true
    end
    return false
end

end

function nextPwr2(n)
    local r = 1
    while r < n do r = r * 2 end
    return r
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
