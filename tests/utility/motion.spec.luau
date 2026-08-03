--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local motion = requireUtility("motion")

    local base = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.1)

    describe("utility.motion", function()
        afterEach(function()
            motion.setSpeed(1)
        end)

        it("leaves a tween alone at the pace it was designed at", function()
            motion.setSpeed(1)
            expect(motion.info(base)).to.equal(base)
        end)

        it("divides durations by the speed, delay included", function()
            motion.setSpeed(2)
            local quick = motion.info(base)
            expect(math.abs(quick.Time - 0.2) < 1e-6).to.equal(true)
            expect(math.abs(quick.DelayTime - 0.05) < 1e-6).to.equal(true)

            motion.setSpeed(0.5)
            local slow = motion.info(base)
            expect(math.abs(slow.Time - 0.8) < 1e-6).to.equal(true)
            expect(math.abs(slow.DelayTime - 0.2) < 1e-6).to.equal(true)
        end)

        it("keeps the shape of the curve, only its length", function()
            motion.setSpeed(2)
            local scaled = motion.info(base)
            expect(scaled.EasingStyle).to.equal(base.EasingStyle)
            expect(scaled.EasingDirection).to.equal(base.EasingDirection)
            expect(scaled.RepeatCount).to.equal(base.RepeatCount)
            expect(scaled.Reverses).to.equal(base.Reverses)
        end)

        it("squares the speed for a spring, so springs and tweens stay together", function()
            -- a spring's settle time goes with the square root of its stiffness, so doubling
            -- the pace means four times the stiffness, not twice
            motion.setSpeed(2)
            expect(motion.stiffness(100)).to.equal(400)

            motion.setSpeed(0.5)
            expect(motion.stiffness(100)).to.equal(25)
        end)

        it("holds the speed inside a usable range", function()
            local low, high = motion.range()

            motion.setSpeed(1000)
            expect(motion.getSpeed()).to.equal(high)

            motion.setSpeed(0)
            expect(motion.getSpeed()).to.equal(low)

            motion.setSpeed(-5)
            expect(motion.getSpeed()).to.equal(low)
        end)

        it("refuses anything that is not a number, nan included", function()
            motion.setSpeed(2)

            motion.setSpeed(0 / 0) -- would poison every duration downstream
            expect(motion.getSpeed()).to.equal(2)

            motion.setSpeed("fast" :: any)
            expect(motion.getSpeed()).to.equal(2)

            motion.setSpeed(nil :: any)
            expect(motion.getSpeed()).to.equal(2)
        end)
    end)
end
