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

local groundShader, unitShader
local cameraPosUniform, modelViewUniform, teamColorUniform

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
            uniform sampler2D heightmap;
            uniform vec3 cameraPos;
            uniform vec2 mapSize;
            uniform float squareSize;

            varying vec3 pos;
            varying vec3 normal;

            void main(void) {
                gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
                pos = gl_Vertex;

                // Thanks for providing the normals, springey.
                // https://en.wikipedia.org/wiki/Finite_difference_coefficient
                float dx = (
                    1.0/12.0 * texture2D(heightmap, (pos.xz + vec2(-2.0*squareSize, 0))/mapSize).x
                    -2.0/3.0 * texture2D(heightmap, (pos.xz + vec2(-squareSize, 0))/mapSize).x
                    +2.0/3.0 * texture2D(heightmap, (pos.xz + vec2(squareSize, 0))/mapSize).x
                    -1.0/12.0 * texture2D(heightmap, (pos.xz + vec2(2.0*squareSize, 0))/mapSize).x
                    )/squareSize;
                float dz = (
                    1.0/12.0 * texture2D(heightmap, (pos.xz + vec2(0, -2.0 * squareSize))/mapSize).x
                    -2.0/3.0 * texture2D(heightmap, (pos.xz + vec2(0, -squareSize))/mapSize).x
                    +2.0/3.0 * texture2D(heightmap, (pos.xz + vec2(0, squareSize))/mapSize).x
                    -1.0/12.0 * texture2D(heightmap, (pos.xz + vec2(0, 2.0 * squareSize))/mapSize).x
                    )/squareSize;
                normal = normalize(cross(vec3(0, dz, 1.0), vec3(1.0, dx, 0)));
            }
        ]],
        fragment = [[
            uniform sampler2D tileTex;
            uniform sampler2D infoTex;
            uniform vec2 infoTexGen;
            uniform vec3 cameraPos;

            varying vec3 pos;
            varying vec3 normal;

            const vec3 lightPos = vec3(1300, 846, 1300);
            const vec3 lightColor = vec3(0.4);

            void main(void) {
                vec3 color;
                color = texture2D(tileTex, pos.xz * vec2(0.01)).rgb;

                normal.x += 0.18 * sin(pos.x * 0.1);
                normal.z += 0.18 * sin(pos.z * 0.1);
                normal = normalize(normal);

                vec3 lightDir = lightPos - pos;
                vec3 cameraDir = cameraPos - pos;
                vec3 halfAngle = normalize(lightDir + cameraDir);
                float lightDist = length(lightDir);
                lightDir = normalize(lightDir);
                float attenuation = 1.0 / (1.0 + 0.00001 * lightDist);
                attenuation = 1.0;

                float intensity = abs(clamp(dot(normal, lightDir), -0.3, 1.0));
                intensity = 0.0;
                // http://page.mi.fu-berlin.de/block/htw-lehre/wise2012_2013/bel_und_rend/skripte/schlick1994.pdf
                float specular = dot(normal, halfAngle);
                specular = specular / (180.0 - 180.0 * specular + specular);

                gl_FragColor = vec4(
                    color * 1.0 +
                    attenuation * (
                        lightColor * color * intensity +
                        lightColor * specular),
                    1.0);
                gl_FragColor.rgb += texture2D(infoTex, pos.xz / infoTexGen).rgb;
                gl_FragColor.rgb -= vec3(0.5);
            }
        ]],
        uniform = {
            mapSize = { Game.mapSizeX, Game.mapSizeZ },
            squareSize = Game.squareSize,
            infoTexGen = { mapPwr2Width, mapPwr2Height },
            cameraPos,
        },
        uniformInt = {
            tileTex = 0,
            infoTex = 3,
            heightmap = 2,
        },
    })
    if (groundShader == nil) then
        Spring.Echo("Tron: Failed to compile ground shader:")
        Spring.Echo(gl.GetShaderLog())
        gadgetHandler:RemoveGadget()
        return
    end
    cameraPosUniform = gl.GetUniformLocation(groundShader, "cameraPos")

    unitShader = gl.CreateShader({
        vertex = [[
            uniform mat4 modelView; // modelview sans unit transform

            varying vec3 pos;
            varying vec3 normal;
            varying vec2 texCoord;
            varying vec3 lightPos;

            const vec3 lightPosWorld = vec3(1300, 846, 1300);

            void main(void) {
                gl_Position = gl_ModelViewMatrix * gl_Vertex;
                pos = gl_Position;
                lightPos = (modelView * vec4(lightPosWorld, 1.0)).xyz;
                gl_Position = gl_ProjectionMatrix * gl_Position;
                normal = gl_NormalMatrix * gl_Normal;
                texCoord = gl_MultiTexCoord0.st;
            }
        ]],
        fragment = [[
            uniform sampler2D diffuseTex;
            uniform sampler2D materialTex;
            uniform vec3 teamColor;

            varying vec3 pos;
            varying vec3 normal;
            varying vec2 texCoord;
            varying vec3 lightPos;

            const vec3 lightColor = vec3(0.8);

            void main(void) {
                vec4 tex1 = texture2D(diffuseTex, texCoord);
                //vec3 color = mix(tex1.rgb, teamColor, tex1.a);
                vec3 color = tex1.rgb;

                vec3 lightDir = lightPos - pos;
                vec3 cameraDir = -pos;
                vec3 halfAngle = normalize(lightDir + cameraDir);
                normal = normalize(normal);
                float lightDist = length(lightDir);
                lightDir = normalize(lightDir);
                float attenuation = 1.0 / (1.0 + 0.00001 * lightDist);
                attenuation = 1.0;

                float intensity = abs(clamp(dot(normal, lightDir), -0.2, 1.0));
                float specular = dot(normal, halfAngle);
                specular = specular / (80.0 - 80.0 * specular + specular);

                gl_FragColor = vec4(mix(
                    color * 0.0 +
                    attenuation * (
                        lightColor * color * intensity +
                        lightColor * specular),
                    teamColor, tex1.a), 1.0);
            }
        ]],
        uniform = {
            teamColor,
            modelView,
        },
        uniformInt = {
            diffuseTex = 0,
            materialTex = 1,
        },
    })
    if (unitShader == nil) then
        Spring.Echo("Tron: Failed to compile unit shader:")
        Spring.Echo(gl.GetShaderLog())
        gadgetHandler:RemoveGadget()
        return
    end
    teamColorUniform = gl.GetUniformLocation(unitShader, "teamColor")
    modelViewUniform = gl.GetUniformLocation(unitShader, "modelView")


    self:ViewResize(w, h)
end

function gadget:ViewResize(w, h)
end

function gadget:DrawWorldPreUnit()
    gl.DepthMask(true)
    gl.DepthTest(GL.LEQUAL)
    gl.Clear(GL.DEPTH_BUFFER_BIT, 1)
    gl.UseShader(groundShader);
    gl.Uniform(cameraPosUniform, Spring.GetCameraPosition())
    gl.Texture(0, "LuaRules/textures/tile.png")
    gl.Texture(2, "$heightmap")
    gl.Texture(3, "$info")
    gl.DrawGroundQuad(0, 0, Game.mapSizeX, Game.mapSizeZ)
    gl.UseShader(0);
    gl.Texture(0, false)
    gl.Texture(2, false)
    gl.Texture(3, false)
    gl.DepthTest(false)
    gl.DepthMask(false)
end

function gadget:DrawWorld()
    gl.DepthMask(true)
    gl.DepthTest(GL.LEQUAL)
    gl.UseShader(unitShader)
    gl.UniformMatrix(modelViewUniform, "camera")
    for unitID,_ in pairs(unitsToDraw) do
        local def = Spring.GetUnitDefID(unitID)
        if def ~= nil and UnitDefs[def].model.type ~= "3do" then
            local tc = { Spring.GetTeamColor(Spring.GetUnitTeam(unitID)) }
            gl.Uniform(teamColorUniform, tc[1], tc[2], tc[3])
            gl.Texture(0, "%" .. def .. ":0")
            gl.Texture(1, "%" .. def .. ":1")
            -- I have to set UnitLuaDraw to true to be able to override unit
            -- rendering, but to actually draw with gl.Unit I have to set it to
            -- false. The hoops I have to jump through...
            Spring.UnitRendering.SetUnitLuaDraw(unitID, false)
            gl.Unit(unitID, true)
            Spring.UnitRendering.SetUnitLuaDraw(unitID, true)
        end
        unitsToDraw[unitID] = nil
    end
    gl.UseShader(0)
    gl.Texture(0, false)
    gl.Texture(1, false)
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
