function moveDummyLinearly(handle, startPos, endPos, steps, delay)
    for i = 1, steps do
        local t = i / steps
        local newPos = {
            startPos[1] * (1 - t) + endPos[1] * t,
            startPos[2] * (1 - t) + endPos[2] * t,
            startPos[3] * (1 - t) + endPos[3] * t
        }
        sim.setObjectPosition(handle, -1, newPos)
        sim.wait(delay)
    end
end

function sysCall_threadmain()
    -- Handles
    local target = sim.getObjectHandle('Target')
    local gripperBase = sim.getObjectHandle('ROBOTIQ_85')
    local attachPoint = sim.getObjectHandle('ROBOTIQ_85_attachPoint')
    local proximitySensor = sim.getObjectHandle('Proximity_sensor')
    local dropDummy = sim.getObjectHandle('DropDummy')
    local finger1 = sim.getObjectHandle('ROBOTIQ_85_active1')
    local finger2 = sim.getObjectHandle('ROBOTIQ_85_active2')

    -- Gripper positions
    local gripperOpen = 0.0
    local gripperClosed = 0.0

    -- Home position
    local homePos = sim.getObjectPosition(target, -1)
    sim.setObjectPosition(target, -1, homePos)
    sim.setJointTargetPosition(finger1, gripperOpen)
    sim.setJointTargetPosition(finger2, gripperOpen)

    -- Drop spacing
    local dropSpacing = 0.017
    local dropCount = 0
    local maxDrops = 8

    while dropCount < maxDrops and sim.getSimulationState() ~= sim.simulation_advancing_abouttostop do
        -- 1. Wait for object to be detected AND stop moving
        local detected = false
        local cubeHandle = nil
        local lastPos = nil

        while not detected do
            local result, _, _, detectedObject = sim.readProximitySensor(proximitySensor)
            if result > 0 and detectedObject ~= -1 then
                cubeHandle = detectedObject
                local currentPos = sim.getObjectPosition(cubeHandle, -1)
                if lastPos then
                    local dx = currentPos[1] - lastPos[1]
                    local dy = currentPos[2] - lastPos[2]
                    local dz = currentPos[3] - lastPos[3]
                    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    if dist < 0.001 then
                        detected = true
                    end
                end
                lastPos = currentPos
            end
            sim.wait(0.05)
        end

        -- 2. Move above the object
        local cubePos = sim.getObjectPosition(cubeHandle, -1)
        local aboveCube = {cubePos[1], cubePos[2], cubePos[3] + 0.15}
        local currentPos = sim.getObjectPosition(target, -1)
        moveDummyLinearly(target, currentPos, aboveCube, 50, 0.01)

        -- 3. Move down to the object
        local atCube = {cubePos[1], cubePos[2], cubePos[3] + 0.025}
        moveDummyLinearly(target, aboveCube, atCube, 30, 0.01)

        -- 4. Close gripper
        sim.setJointTargetPosition(finger1, gripperClosed)
        sim.setJointTargetPosition(finger2, gripperClosed)
        sim.wait(1.0)

        -- 5. Attach object to gripper
        sim.setObjectParent(cubeHandle, attachPoint, true)

        -- 6. Move up with object
        moveDummyLinearly(target, atCube, aboveCube, 30, 0.01)
        
        -- 7. Calculate this object's drop position
        local baseDrop = sim.getObjectPosition(dropDummy, -1)
        local dropX = baseDrop[1] + dropCount * dropSpacing
        local dropY = baseDrop[2]
        local dropZ = baseDrop[3]
        local aboveDrop = {dropX, dropY, dropZ + 0.15}
        local atDrop = {dropX, dropY, dropZ + 0.025}

        -- 8. Move above drop location
        moveDummyLinearly(target, aboveCube, aboveDrop, 50, 0.01)

        -- 9. Move down to drop
        moveDummyLinearly(target, aboveDrop, atDrop, 30, 0.01)

        -- 10. Open gripper
        sim.setJointTargetPosition(finger1, gripperOpen)
        sim.setJointTargetPosition(finger2, gripperOpen)
        sim.wait(1.0)

        -- 11. Detach object
        sim.setObjectParent(cubeHandle, -1, true)

        -- 12. Move up from drop
        moveDummyLinearly(target, atDrop, aboveDrop, 30, 0.01)

        -- 13. Return to home
        moveDummyLinearly(target, aboveDrop, homePos, 50, 0.01)

        -- 14. Increment drop count
        dropCount = dropCount + 1

        sim.wait(0.5)
    end
end
