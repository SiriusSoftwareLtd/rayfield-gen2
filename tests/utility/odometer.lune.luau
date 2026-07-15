--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any

return function()
    local odometer = helpers.requireUtility("odometer")

    local function makeWindow(): any
        local window = {
            created = {},
            theme = {
                Font = Font.new("font://spec", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                ContentColor = Color3.fromRGB(255, 255, 255),
            },
        }

        function window:Create(className, properties)
            local instance = Instance.new(className)
            for property, value in properties or {} do
                local target = instance :: any
                target[property] = value
            end
            table.insert(self.created, instance)
            return instance
        end

        function window:_reveal(instance, properties)
            for property, value in properties do
                local target = instance :: any
                target[property] = value
            end
        end

        return window
    end

    local function makeOdometer(options: any?)
        local window = makeWindow()
        local container = Instance.new("Frame")
        container.ZIndex = 2
        local odo = odometer.new(window, container, options or { textSize = 12, transparency = 1, duration = 0.1 })
        return odo, window, container
    end

    describe("utility.odometer", function()
        it("snaps digits and static characters from the right", function()
            local odo = makeOdometer()

            odo:snap("12%")

            expect(odo.length).to.equal(3)
            expect(odo.slots[0].static.Text).to.equal("%")
            expect(odo.slots[1].reel.digit).to.equal(2)
            expect(odo.slots[2].reel.digit).to.equal(1)
            expect(odo.slots[0].static.Visible).to.equal(true)
            expect(odo.slots[1].reel.cell.Visible).to.equal(true)
        end)

        it("skips unchanged text and reuses hidden slots", function()
            local odo, window = makeOdometer()

            odo:snap("100")
            local firstReel = odo.slots[2].reel
            local created = #window.created

            odo:snap("100")
            expect(#window.created).to.equal(created)

            odo:snap("9")
            expect(odo.slots[1].reel.cell.Visible).to.equal(false)
            expect(odo.slots[2].reel.cell.Visible).to.equal(false)

            odo:snap("109")
            expect(odo.slots[2].reel).to.equal(firstReel)
            expect(odo.slots[2].reel.cell.Visible).to.equal(true)
        end)

        it("rolls to new digits and settles on tween completion", function()
            local odo = makeOdometer()

            odo:snap("19")
            odo:to("20", true)

            expect(odo.slots[0].reel.digit).to.equal(0)
            expect(odo.slots[1].reel.digit).to.equal(2)
            expect(odo.slots[0].reel.stripTween).never.to.be.ok()
            expect(odo.slots[1].reel.sizeTween).never.to.be.ok()

            odo:to("18", false)
            expect(odo.slots[0].reel.digit).to.equal(8)
            expect(odo.slots[1].reel.digit).to.equal(1)
        end)

        it("reveals visible static labels and reel labels", function()
            local odo = makeOdometer()

            odo:snap("7A")
            odo:reveal(0.25, false)

            expect(odo.transparency).to.equal(0.25)
            expect(odo.slots[0].static.TextTransparency).to.equal(0.25)

            local touchedDigitLabel = false
            for _, label in odo.slots[1].reel.strip:GetChildren() do
                if label:IsA("TextLabel") then
                    touchedDigitLabel = true
                    expect(label.TextTransparency).to.equal(0.25)
                end
            end
            expect(touchedDigitLabel).to.equal(true)
        end)
    end)
end
