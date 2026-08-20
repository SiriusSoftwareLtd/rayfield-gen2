local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")
    local locale = helpers.requireUtility("locale")

    describe("component divider", function()
        local window

        local function makeWindow()
            window = Window.new({
                name = "Divider Window",
                configuration = { autoSave = false, autoLoad = false },
            })
            return window
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil

            -- the locale module is shared state; drop the test locale so it can't leak
            locale.strings["zz-test"] = nil
            locale.setActive("en")
        end)

        it("draws a rule across the page, with or without a word in it", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })

            local plain = tab:CreateDivider()
            expect(plain.__type).to.equal("Divider")
            expect(plain.left).to.be.ok()
            expect(plain.title).to.equal(nil)
            expect(plain.right).to.equal(nil) -- one span, not two halves
            expect(table.find(tab.elements, plain)).to.be.ok()

            -- a word in the middle splits the rule, so it stays centred whatever the word is
            local named = tab:CreateDivider({ text = "Advanced" })
            expect(named.title.Text).to.equal("Advanced")
            expect(named.left).to.be.ok()
            expect(named.right).to.be.ok()

            named:Set("Danger")
            expect(named.title.Text).to.equal("Danger")

            named:Set("")
            expect(named.title.Visible).to.equal(false)
            -- and the rule closes back up rather than leaving the gap the label sat in
            expect(named.right.Visible).to.equal(false)
            expect(named.left.Visible).to.equal(true)

            named:Set("Back again")
            expect(named.title.Visible).to.equal(true)
            expect(named.right.Visible).to.equal(true)
        end)

        it("grows a label on the first Set rather than doing nothing", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })

            local plain = tab:CreateDivider()
            plain:Set("Named later")
            expect(plain.title).to.be.ok()
            expect(plain.title.Text).to.equal("Named later")
            expect(plain.title.Visible).to.equal(true)
            expect(plain.right).to.be.ok() -- the rule splits to make room for it

            -- clearing one that never had a word is the state it is already in, not a no-op trap
            local untouched = tab:CreateDivider()
            untouched:Set("")
            expect(untouched.title).to.equal(nil)

            -- a spacer has no rule to split, but it can still be given a word
            local spacer = tab:CreateDivider({ line = false, spacing = 20 })
            spacer:Set("Room with a word")
            expect(spacer.title.Text).to.equal("Room with a word")
            expect(spacer.left).to.equal(nil)
            expect(spacer.main.Size.Y.Offset).to.equal(54) -- 20 above, 20 below, 14 of label

            -- one grown after the page is up comes in on its own, not fully transparent
            w.hidden = false
            local late = tab:CreateDivider()
            late:Set("Late")
            expect(late.title.TextTransparency < 1).to.equal(true)
        end)

        it("gives room and no rule when asked for one", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })

            -- the other thing a divider gets reached for, and the only way to get it
            local space = tab:CreateDivider({ line = false, spacing = 20 })
            expect(space.left).to.equal(nil)
            expect(space.main.Size.Y.Offset).to.equal(40)

            local rule = tab:CreateDivider({ spacing = 8 })
            expect(rule.main.Size.Y.Offset).to.equal(17)

            -- default spacing when none is given, and a label takes the room the rule would
            local plain = tab:CreateDivider()
            expect(plain.main.Size.Y.Offset).to.equal(25)

            local named = tab:CreateDivider({ text = "Advanced" })
            expect(named.main.Size.Y.Offset).to.equal(38)
        end)

        it("keeps a label set after the fact through a language change", function()
            local w = makeWindow()
            w:RegisterTranslations({
                ["zz-test"] = {
                    ["Built with this"] = "Bwt",
                    ["Set after the fact"] = "Satf",
                },
            })

            local tab = w:CreateTab({ name = "Main" })
            local divider = tab:CreateDivider({ text = "Built with this" })
            divider:Set("Set after the fact")

            -- the window re-resolves every localised property from the source it was bound to,
            -- so text written straight to the label would be replaced here by a translation of
            -- the word it no longer shows
            w:SetLocale("zz-test")
            expect(divider.title.Text).to.equal("Satf")

            -- and setting again while a language is active still lands
            divider:Set("Built with this")
            expect(divider.title.Text).to.equal("Bwt")

            w:SetLocale("en")
            expect(divider.title.Text).to.equal("Built with this")
        end)

        it("fades with the rest of the page", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local divider = tab:CreateDivider({ text = "Advanced" })

            divider:_setShown(false, false)
            expect(divider.left.BackgroundTransparency).to.equal(1)
            expect(divider.right.BackgroundTransparency).to.equal(1)
            expect(divider.title.TextTransparency).to.equal(1)

            divider:_setShown(true, false)
            expect(divider.left.BackgroundTransparency < 1).to.equal(true)
            expect(divider.right.BackgroundTransparency < 1).to.equal(true)
            expect(divider.title.TextTransparency < 1).to.equal(true)

            -- and one with no rule has nothing to fade, which must not error
            local space = tab:CreateDivider({ line = false })
            space:_setShown(true, false)
            space:_setShown(false, false)
        end)

        it("restyles on a theme change", function()
            local w = makeWindow()
            local frost = helpers.requireTheme("frost")
            local tab = w:CreateTab({ name = "Main" })
            local divider = tab:CreateDivider({ text = "Advanced" })

            expect(divider.left.BackgroundColor3).never.to.equal(frost.ContentColor)

            w:ChangeTheme("frost")
            expect(divider.left.BackgroundColor3).to.equal(frost.ContentColor)
            expect(divider.right.BackgroundColor3).to.equal(frost.ContentColor)
            expect(divider.title.TextColor3).to.equal(frost.ContentColor)
        end)

        it("holds no value, so nothing about it is saved", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local divider = tab:CreateDivider({ text = "Advanced" })

            expect(divider.flag).to.equal(nil)
            expect(divider.value).to.equal(nil)
            for _, control in w.controls do
                expect(control).never.to.equal(divider)
            end
        end)

        it("reorders like every other element", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            tab:CreateButton({ name = "First" })
            local divider = tab:CreateDivider()

            divider:MoveToTop()
            expect(tab.elements[1]).to.equal(divider)

            divider:MoveToBottom()
            expect(tab.elements[#tab.elements]).to.equal(divider)
        end)

        it("goes home when its tab is removed, connections and all", function()
            local w = makeWindow()
            local connectionsBefore = #w.connections

            local tab = w:CreateTab({ name = "Doomed" })
            local divider = tab:CreateDivider({ text = "Advanced" })
            local instancesBefore = #w.instances

            tab:Remove()
            expect(#w.instances < instancesBefore).to.equal(true)
            expect(#w.connections).to.equal(connectionsBefore)
            expect(divider.connections).to.equal(nil)
        end)

        it("builds in a column but not in a row", function()
            local logModule = helpers.requireUtility("log")
            local originalWarn = logModule.warn
            local warned = false
            logModule.warn = function(...)
                warned = warned or tostring((...)):find("a row only holds compact elements", 1, true) ~= nil
            end

            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })

            local column = tab:CreateGroup({ direction = "column" })
            expect(column:CreateDivider().__type).to.equal("Divider")

            local row = tab:CreateGroup({ direction = "row" })
            expect(row:CreateDivider()).to.equal(nil)
            expect(warned).to.equal(true)

            logModule.warn = originalWarn
        end)
    end)
end
