import Testing
@testable import LumaDesignSystem

@Suite("Reduce Transparency attenuation")
struct TranslucencyTests {
    @Test("passes the base opacity through when the trait is off")
    func passthrough() {
        #expect(Translucency.attenuated(0.55, reduceTransparency: false) == 0.55)
        #expect(Translucency.attenuated(0.16, reduceTransparency: false) == 0.16)
    }

    @Test("removes translucency when the trait is on")
    func attenuated() {
        // Every translucent layer collapses to fully transparent; the solid
        // base treatment underneath carries legibility.
        for base in [0.09, 0.16, 0.22, 0.45, 0.55, 0.70] {
            #expect(Translucency.attenuated(base, reduceTransparency: true) < base)
            #expect(Translucency.attenuated(base, reduceTransparency: true) == 0)
        }
    }
}
