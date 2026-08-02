--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local spring = requireUtility("spring")

    -- a frame at 60fps, which is what the thing is stepped with in practice
    local frame = 1 / 60

    local function run(instance, frames: number)
        for _ = 1, frames do
            instance:step(frame)
        end
        return instance.position
    end

    describe("utility.spring", function()
        it("travels to its target and stops there", function()
            local motion = spring.new(Vector2.zero, 300, 1)
            motion:setTarget(Vector2.new(400, 0))

            run(motion, 60)
            expect((motion.position - motion.target).Magnitude < 1).to.equal(true)
            expect(motion:settled(1)).to.equal(true)
        end)

        it("takes longer over a longer distance", function()
            local near = spring.new(Vector2.zero, 300, 1)
            near:setTarget(Vector2.new(20, 0))
            local far = spring.new(Vector2.zero, 300, 1)
            far:setTarget(Vector2.new(400, 0))

            local frames = 0
            while not near:settled(1) and frames < 600 do
                near:step(frame)
                far:step(frame)
                frames += 1
            end

            -- the short move is done and the long one is not, which is the whole point of a
            -- speed rather than a duration
            expect(near:settled(1)).to.equal(true)
            expect(far:settled(1)).to.equal(false)
        end)

        it("keeps its speed when the target moves, instead of starting again", function()
            local motion = spring.new(Vector2.zero, 300, 1)
            motion:setTarget(Vector2.new(400, 0))
            run(motion, 8)

            local carried = motion.velocity
            expect(carried.X > 0).to.equal(true)

            -- turned around mid flight: the velocity it had is still there on the next step,
            -- which is what bends the path rather than snapping it
            motion:setTarget(Vector2.zero)
            expect(motion.velocity).to.equal(carried)

            motion:step(frame)
            expect(motion.velocity.X < carried.X).to.equal(true)
        end)

        it("overshoots below critical damping and not at or above it", function()
            local loose = spring.new(Vector2.zero, 300, 0.6)
            loose:setTarget(Vector2.new(200, 0))
            local dead = spring.new(Vector2.zero, 300, 1)
            dead:setTarget(Vector2.new(200, 0))

            local loosePeak, deadPeak = 0, 0
            for _ = 1, 120 do
                loosePeak = math.max(loosePeak, loose:step(frame).X)
                deadPeak = math.max(deadPeak, dead:step(frame).X)
            end

            expect(loosePeak > 200).to.equal(true)
            expect(deadPeak <= 200.01).to.equal(true)
        end)

        it("survives a frame that took far too long", function()
            local motion = spring.new(Vector2.zero, 300, 1)
            motion:setTarget(Vector2.new(400, 0))

            -- a two second hitch. Stepped raw this diverges and never comes back; the fixed
            -- internal step is what keeps it on the rails
            motion:step(2)
            expect(motion.position.Magnitude < 1e4).to.equal(true)

            run(motion, 120)
            expect((motion.position - motion.target).Magnitude < 1).to.equal(true)
        end)

        it("does not call itself settled at the top of an overshoot", function()
            local motion = spring.new(Vector2.zero, 300, 0.5)
            motion:setTarget(Vector2.new(200, 0))

            -- somewhere in here it passes straight through the target at speed, and distance
            -- alone would call that done with the whole return trip still to come
            local calledEarly = false
            for _ = 1, 40 do
                motion:step(frame)
                if motion:settled(1) and motion.velocity.Magnitude > 30 then
                    calledEarly = true
                end
            end
            expect(calledEarly).to.equal(false)
        end)

        it("snaps dead on demand", function()
            local motion = spring.new(Vector2.zero, 300, 1)
            motion:setTarget(Vector2.new(400, 0))
            run(motion, 10)

            motion:snap(Vector2.new(50, 50))
            expect(motion.position).to.equal(Vector2.new(50, 50))
            expect(motion.velocity).to.equal(Vector2.zero)
            expect(motion:settled(0.01)).to.equal(true)
        end)
    end)
end
