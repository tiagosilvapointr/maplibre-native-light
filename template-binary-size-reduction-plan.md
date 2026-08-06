# MapLibre Native — Binary Size Reduction Plan: C++ Template Instantiation

- **Date:** 2026-06-05
- **Author / generating model:** Claude Opus 4.8 (`claude-opus-4-8`), via Claude Code
- **Source data:** `ios-layer-size-reports/20260604-213905/baseline/bloaty_symbols_file_all.txt`
- **Binary measured:** `platform/ios:MapLibre.dynamic` (iOS framework, unstripped). Shipped stripped artifact ≈ **6.3 MB** (`MapLibre.stripped`).

---

## 1. Executive summary

Template-generated code is a **real and addressable** contributor to MapLibre's iOS binary size, but the popular framing — *"convert templates to iterative code"* — is only partially correct and needs to be stated precisely up front:

- The size cost of templates is **not** that loops get unrolled. It is **monomorphization**: the compiler emits a *separate copy* of every function for every distinct type combination it is instantiated with. The lever is therefore **reducing the number of distinct instantiations and the per-instantiation code size**, not rewriting algorithms as runtime `for` loops.
- "Converting to regular iterative code" is the right intuition for exactly one class of these: **compile-time recursion / fold-expression / variadic dispatch** over type lists (`std::apply`, `util::ignore({...})`, `mapbox::variant` visitation, parameter-pack expansion). Those genuinely *can* be turned into runtime loops over `std::array`/`std::vector`, with large wins.
- For the rest, the correct tools are **type erasure**, **base-class hoisting (non-template common code)**, **`extern template` / explicit instantiation**, and **outlining**. The codebase already demonstrates the right pattern in one place (`PropertyExpressionBase` hoists all non-`T`-dependent logic out of `PropertyExpression<T>`), and that pattern should be replicated.

### Measured impact (from bloaty, this baseline)

| Bucket | Size | Notes |
|---|---:|---|
| File total (unstripped) | 15.16 MiB | |
| `__LINKEDIT` (symbol/debug tables) | 9.55 MiB | **stripped away in the shipped binary** — ignore for ship-size |
| Raw `[__TEXT,…]` / `[__DATA,…]` sections | 0.72 MiB | cstrings, unwind info, ObjC metadata |
| **Symbolized code + data** | **5.61 MiB** | this is the body we can shrink |
| → of which, symbols whose name contains `<…>` (template instantiations) | **1.43 MiB** | **≈ 25.4% of symbolized code** |

So roughly **one quarter** of the actual code is template-instantiated. Not all of it is recoverable (much is `std::` library glue that is unavoidable), but the top families below are concentrated, self-inflicted, and tractable.

### Top template families (aggregated across all ~29k symbols)

| Rank | Family | Size | # syms | Tractability |
|---:|---|---:|---:|---|
| 1 | `mbgl::style::expression::*` (Signature, Converter, evaluate) | 194.5 KiB | 622 | **High** — variadic `Signature<Fn>` dispatch |
| 2 | `std::vector<>` / `__split_buffer` glue | 185.7 KiB | 27 | Medium — dedupe element types |
| 3 | `std::__hash_table<>` (unordered_map/set) | 114.3 KiB | 33 | Medium — dedupe key/value types |
| 4 | `mbgl::style::conversion::Converter<>` / `convertFunctionToExpression` | 103.7 KiB | 79 | **High** — per-type `operator()` |
| 5 | `std::__tree<>` (map/set) | 88.1 KiB | 28 | Medium — dedupe |
| 6 | `mbgl::style::Properties<>` (Unevaluated/Transitionable/Transitioning) | 72.9 KiB | 24 | **High** — per-layer monomorphization |
| 7 | `std::__function` (`std::function` glue) | 66.4 KiB | 9 | Medium — outline / `function_ref` |
| 8 | `mapbox::util::variant` + `dispatcher::apply` | 64.7 KiB | 12 | **High** — visitation dispatch |
| 9 | `MLNStyleValueTransformer<>` (ObjC↔mbgl bridge) | 61.3 KiB | 6 | **High** — per-value-type |
| 10 | `mbgl::actor::*` / `ActorRef` / `makeMessage` / `MessageImpl` | 47.8 KiB | 10 | Medium — per-message-signature |
| 11 | `std::shared_ptr`/`tuple` glue | 34.1 KiB | 11 | Low |
| 12 | `mbgl::mtl::ShaderGroup<>::getOrCreateShader` | 32.9 KiB | 8 | Medium — per-shader |
| 13 | `ankerl::unordered_dense` | 31.7 KiB | 31 | Low |
| 14 | `mbgl::*Layout` (PatternLayout etc.) | 29.7 KiB | 43 | Medium |
| 15 | `std::__introsort` (single 28.8 KiB symbol) | 28.8 KiB | 1 | **High** — one outsized sort |

The **High-tractability** families (1, 4, 6, 8, 9) total **≈ 497 KiB** of code and are the focus of this plan. Realistic recoverable target after refactors: **150–300 KiB of `__TEXT`** (i.e. a few percent off the shipped 6.3 MB), with secondary wins in compile time and `__LINKEDIT`/dSYM size.

---

## 2. Methodology & how to re-measure

1. **Always measure the stripped binary for ship-size claims.** The bloaty report here is on the unstripped framework, so 63% is `__LINKEDIT` noise. Re-run bloaty against `MapLibre.stripped` (already present in the baseline dir) or pass `--debug-file` for symbol mapping. The script is `scripts/ios-layer-size-bloaty.sh`.
2. **Compare like-for-like.** For each change, produce a new dated report dir under `ios-layer-size-reports/` and diff with `bloaty -- new old` to get a signed delta. Do not eyeball percentages between unstripped runs.
3. **Watch three numbers per change:** (a) stripped `__TEXT` size, (b) total stripped file size, (c) clean build wall-time (templates dominate compile time too).
4. **Guard against regressions** with the existing render tests (`bazel test //...`) and the iOS unit tests — these refactors are behavior-preserving and must stay green.

---

## 3. Why each family is large, and the conversion strategy

### Target A — `mbgl::style::conversion::Converter<T>::operator()` (103.7 KiB) and `convertFunctionToExpression` (High)

**Why it's big:** Style parsing instantiates `Converter<T>` for every style-spec type (each layer's paint/layout property set, each source option type, filter, light, transition, position, rotation, …). The 35.3 KiB single `Converter<>::operator()()` symbol plus 79 related symbols are the JSON→typed-value conversion bodies, each fully monomorphized. `MLNStyleValueTransformer<>::toPropertyValue<>()` (33.8 KiB) is the Objective-C mirror of the same problem.

**Strategy — type-erase the leaf conversions to a runtime-dispatched core:**
- The outer `Converter<T>` is a thin façade; the bulk of `operator()` is identical control flow that differs only in (1) the expected JSON shape and (2) the final typed construction. Hoist the shape-checking / error-reporting / array-walking into **non-template free functions** that operate on `Convertible` + a small descriptor, and keep only the final `T`-typed construction in the template.
- Concretely: introduce `bool convertNumberArray(const Convertible&, double* out, size_t n, Error&)`, `convertColorLike(...)`, etc., as ordinary functions, and have `Converter<std::array<float,4>>` / `Converter<Color>` / … call them. The per-type symbol shrinks to a few instructions.

```cpp
// Before: each Converter<T> re-emits the whole walk+validate body.
template <>
struct Converter<std::array<float, 4>> {
    std::optional<std::array<float,4>> operator()(const Convertible& v, Error& err) const {
        if (!isArray(v) || arrayLength(v) != 4) { err = {"expected 4 numbers"}; return {}; }
        std::array<float,4> result;
        for (size_t i = 0; i < 4; ++i) {
            auto n = toNumber(arrayMember(v, i));
            if (!n) { err = {"expected number"}; return {}; }
            result[i] = static_cast<float>(*n);
        }
        return result;
    }
};

// After: shared non-template core; template body is a 3-line shim.
bool convertFloatArray(const Convertible& v, float* out, std::size_t n, Error& err); // .cpp, emitted once

template <std::size_t N>
struct Converter<std::array<float, N>> {
    std::optional<std::array<float,N>> operator()(const Convertible& v, Error& err) const {
        std::array<float,N> r;
        return convertFloatArray(v, r.data(), N, err) ? std::optional{r} : std::nullopt;
    }
};
```

- **Pros:** Large, direct win; touches a hot, self-contained subsystem; improves compile time noticeably.
- **Cons / risks:** `Converter` specializations are spread across ~16 headers in `include/mbgl/style/conversion/`; care needed to keep error messages byte-identical (tests assert on them). Some converters are genuinely type-specific and won't factor.
- **Effort:** Medium (1–2 weeks, incremental per converter).

### Target B — `mbgl::style::Properties<...>` per-layer monomorphization (72.9 KiB) (High)

**Why it's big:** There are **11 layer property sets** and **13 render layers**. Each `Properties<P0,P1,…>` instantiates `Unevaluated::maybeEvaluate` (11.9 KiB), `Transitionable::transitioned`/`untransitioned` (8.2 + 7.4 KiB), `Unevaluated::evaluate`, etc. The bodies are *structurally identical fold-expressions over the property pack* — only the element types differ.

**Strategy — this is the genuine "templates → iterative loop" case.** The per-property work is currently a compile-time `util::ignore({ (f(get<Ps>()))... })` pack expansion that emits straight-line code N properties long, duplicated per layer. Replace the *traversal* with a runtime loop over a `std::array` of type-erased property descriptors (function pointers), while keeping each property's typed lambda as a tiny outlined function:

```cpp
// Before (in Properties<Ps...>): N-way pack expansion, re-emitted per layer set.
Unevaluated maybeEvaluate(const PropertyEvaluationParameters& p) const {
    Unevaluated result;
    util::ignore({ (result.template get<Ps>() = get<Ps>().maybeEvaluate(p), 0)... });
    return result;
}

// After: one shared loop over a static descriptor table; per-property work is a
// non-inline function pointer, emitted once per property type (shared across layers
// that reuse the same property), not once per layer set.
struct PropDesc { void (*maybeEval)(const void* in, void* out, const Params&); };
static constexpr std::array<PropDesc, sizeof...(Ps)> kDescs = { /* &maybeEvalOne<Ps>... */ };

Unevaluated maybeEvaluate(const Params& p) const {
    Unevaluated result;
    for (std::size_t i = 0; i < kDescs.size(); ++i)
        kDescs[i].maybeEval(slot(i), result.slot(i), p);   // runtime loop, single body
    return result;
}
```

- **Pros:** Directly collapses N× per-layer duplication into one loop body + a deduplicated set of per-property functions. Properties shared across layers (e.g. `opacity`, `color`) get instantiated once total instead of once per layer.
- **Cons / risks:** This is the **most invasive** change. `Properties` uses `IndexedTuple` with heterogeneous storage; introducing `void*` slot access defeats some type safety and must be wrapped carefully (offset table generated at compile time). Inlining loss could cost a little runtime in evaluation hot paths — **must be benchmarked** (property evaluation runs per-feature). Prefer doing this only for the *cold* paths (`transitioned`/`untransitioned`/`maybeEvaluate`, which run per-style-change, not per-frame) and **leave the per-frame `evaluate()` fully templated/inlined.**
- **Effort:** Large (2–4 weeks); stage it: cold paths first, measure, stop if per-frame paths show regression.

### Target C — `mapbox::util::variant` visitation + `dispatcher::apply` (64.7 KiB) (High)

**Why it's big:** `variant::apply_visitor` / `dispatcher<>::apply<>` (29.6 KiB single symbol) generates a recursive type-switch instantiated for every (variant, visitor) pair. `Value`, `PropertyValue<T>`, `Convertible`, geometry types all use it.

**Strategy:** Two complementary moves:
1. **Switch on the runtime index instead of recursive template dispatch** where the variant alternative count is fixed and small — a `switch (v.which())` with `get<I>()` is a single non-recursive body and the compiler emits a jump table. mapbox::variant's `apply` is recursive-template by construction; a hand-written switch for the hottest variants (`expression::Value`, `Convertible`) removes the recursion-unrolled code.
2. **Deduplicate visitors.** Many call sites pass an inline lambda that does the same thing; hoist these into named function objects so the `(variant × visitor)` product collapses.

```cpp
// Before: recursive template dispatch, one full body per visitor type.
return v.match([](const std::string& s){ return f(s); },
               [](double d){ return f(d); }, /* ...N alternatives... */);

// After: flat switch on the discriminant; one body, jump table.
switch (v.which()) {
    case Type::String: return f(v.get_unchecked<std::string>());
    case Type::Number: return f(v.get_unchecked<double>());
    /* ... */
}
```

- **Pros:** Removes the recursive monomorphization; often *faster* (jump table vs. chained branches).
- **Cons / risks:** Loses exhaustiveness checking that `match` gives; mitigate with a `default: unreachable()` plus a `static_assert` on alternative count so adding a variant member breaks the build. Must be applied surgically (don't rewrite all `.match()` call sites — only the few that dominate the report).
- **Effort:** Medium.

### Target D — `mbgl::style::expression::Signature<Fn>` / `applyImpl` / `CompoundExpression` (part of 194.5 KiB) (High)

**Why it's big:** `compound_expression.cpp` registers ~100 built-in expression operators. Each is wrapped in a `Signature<R(Args...)>` whose `Signature()` ctor (9.5 KiB) and `applyImpl<>` (9.2 KiB) are instantiated **once per distinct function signature** — and the argument-unpacking `applyImpl` uses index-sequence pack expansion to pull each typed arg out of `std::vector<Value>`.

**Strategy:** Reduce the number of *distinct* `Signature` instantiations by normalizing signatures:
- Many operators share the same arity/type shape (`(double,double)->double`, `(Value,Value)->bool`, …). Route them through a **small fixed set of erased adapters** keyed on `(arity, argType, returnType)` that read args from the `std::vector<Value>` via a runtime loop, instead of a unique `applyImpl<Idx...>` per lambda type.
- Keep the lambda bodies (the actual math) but call them through a uniform `Value(*)(const Value* args, size_t n)` thunk.

```cpp
// Before: applyImpl<Indices...> instantiated per Signature<Fn>.
template <std::size_t... I>
EvaluationResult applyImpl(const EvaluationContext& ctx,
                           const Args& args, std::index_sequence<I...>) const {
    return fn(evaluate<std::tuple_element_t<I, Params>>(args[I], ctx)...); // unrolled per Fn
}

// After: one runtime arg-marshalling loop shared by all same-shape signatures.
EvaluationResult applyErased(const EvaluationContext& ctx, const Args& args) const {
    Value buf[kMaxArgs];
    for (std::size_t i = 0; i < args.size(); ++i)
        if (auto v = coerce(argKinds[i], args[i], ctx)) buf[i] = *v; else return error(...);
    return thunk(buf, args.size());   // thunk wraps the original lambda
}
```

- **Pros:** Collapses ~100 unique `applyImpl`/`Signature` instantiations toward a handful; sizeable compile-time win too.
- **Cons / risks:** `compound_expression.cpp` is intricate and well-tested; the typed-arg coercion currently happens at compile time via `std::tuple_element_t`. Moving it to a runtime `argKinds[]` table is correct but must preserve exact coercion/error semantics (expression conformance tests are strict). Slight per-call overhead — acceptable since expression evaluation already goes through virtual `Expression::evaluate`.
- **Effort:** Medium–Large.

### Target E — `MLNStyleValueTransformer<>` (61.3 KiB, 6 symbols) (High)

**Why it's big:** The Darwin bridge instantiates this transformer for each mbgl value type ↔ `MLNStyleValue` pairing (`toPropertyValue`, `getMBGLValue`, `PropertyExpressionEvaluator`). Same monomorphization-per-type issue, in `platform/darwin/src/MLNStyleValue_Private.h`.

**Strategy:** Identical to Target A — push the JSON/NSExpression walking and error handling into non-template `.mm` helpers; keep only the final typed box/unbox in the template. Because this is header-only template code included by many `.mm` translation units, it is **also duplicated across TUs** before the linker folds it — moving bodies to a single `.mm` is a pure win.

- **Pros:** Header-to-source move alone (no algorithm change) deduplicates across translation units; low risk.
- **Cons:** ObjC++ bridging types are fiddly; ARC interactions with helper signatures need care.
- **Effort:** Small–Medium. **Good first candidate / quick win.**

---

## 4. Cross-cutting, low-risk levers (do these first)

These require **no algorithmic rewrite** and recover size across *all* families simultaneously:

1. **`extern template` for the hot instantiations.** The codebase currently uses **zero** `extern template` declarations. For widely-included templates (`PropertyExpression<float>`, `PropertyExpression<Color>`, `Properties<...>` per layer, `Converter<...>`, the common `std::vector`/`std::map` element types), declare `extern template` in the header and a single explicit instantiation in one `.cpp`. This stops every translation unit from emitting its own copy and leaning on the linker to fold them — cutting both object-file size, link time, and occasionally final size where folding is imperfect (e.g. across the Metal/ObjC boundary).

   ```cpp
   // property_expression.hpp
   extern template class PropertyExpression<float>;
   extern template class PropertyExpression<Color>;
   // property_expression.cpp
   template class PropertyExpression<float>;
   template class PropertyExpression<Color>;
   ```
   - **Pros:** Mechanical, behavior-preserving, reversible, immediate compile-time win. **Lowest risk / highest ratio.**
   - **Cons:** Must enumerate the instantiation set; a missed type becomes a link error (which is self-correcting — you just add it).

2. **Replicate the `PropertyExpressionBase` pattern.** `PropertyExpression<T>` already hoists *all* non-`T` logic into a non-template base (`property_expression.hpp:22`). Audit the other big templates (`Transitioning<Value>`, `MLNStyleValueTransformer<>`, `ShaderGroup<>`) for members that don't depend on the template parameter and pull them into a non-template base or free function. This is the single most effective *general* technique and it's already idiomatic here.

3. **Outline the one giant `std::__introsort<>` (28.8 KiB).** A single sort instantiation is unusually large — find the call site (likely sorting a large struct by value) and sort indices / pointers instead, or pass a non-generic comparator, to shrink the instantiated body.

4. **`std::function` → `mbgl::util::unique_function` / `function_ref` on hot, non-owning callbacks.** The 66 KiB of `__function` glue (`__func::operator()`, `__clone`, `~__func`, `__func<>` vtables) comes from `std::function`'s type-erased heap machinery. Where a callback is *non-owning and synchronous* (the common `eachChild(const std::function<void(const Expression&)>&)` visitor at `compound_expression.hpp:37` is a textbook case), switch to a `function_ref`-style non-owning view — no allocation, no clone/destroy instantiation.

5. **Deduplicate container element types.** `std::vector<>`/`__hash_table<>`/`__tree<>` glue (388 KiB combined) scales with the number of *distinct* element/key types. Where small structs are stored by value in many maps, consider storing by `shared_ptr`/index, or introducing a common erased node type, so N element types collapse to one. Lower priority (much of this is unavoidable), but `__emplace_back_slow_path` at 54.7 KiB and `__emplace_unique_key_args` at 43.3 KiB are worth checking for a single dominant element type.

---

## 5. Recommended sequencing

| Phase | Work | Risk | Est. recovered `__TEXT` | Gate |
|---|---|---|---:|---|
| **0** | Re-baseline bloaty on the **stripped** binary; wire `bloaty -- new old` diff into the report script | none | — | reproducible signed deltas |
| **1** | `extern template` for hot instantiations (lever 1) + move `MLNStyleValueTransformer` bodies to `.mm` (Target E / lever 2) | low | 40–80 KiB | tests green, no perf change |
| **2** | `Converter<T>` shared cores (Target A) + outline the giant introsort (lever 3) | low–med | 50–90 KiB | style-parse error-message tests byte-identical |
| **3** | variant visitation switches on hottest variants (Target C) + `function_ref` on non-owning visitors (lever 4) | med | 40–70 KiB | expression conformance + render tests |
| **4** | `Signature`/`applyImpl` erasure in `compound_expression.cpp` (Target D) | med–large | 60–120 KiB | full expression test suite + microbench |
| **5** | `Properties<>` cold-path loop-ification (Target B) — **cold paths only**, benchmark per-frame eval | large | 40–70 KiB | render-test perf no regression |

Stop-loss rule: after each phase, if the **stripped** delta is < ~10 KiB or any per-frame benchmark regresses > 2%, revert that phase and move on. Phases 1–2 are safe to land regardless.

---

## 6. Honest caveats

- **The headline 25% is of *symbolized code*, not of the shipped binary.** Of the shipped ~6.3 MB, a meaningful fraction is third-party data (Harfbuzz/FreeType tables — `propsVectorsTrie`, `_ft_adobe_glyph_list`, `_hb_ucd_*`, ICU `ubidi_props`), ObjC metadata, and cstrings that templates don't touch. A realistic, well-executed campaign recovers **single-digit-percent of ship size**, not 25%. The compile-time and dSYM-size wins are proportionally larger and worth it on their own.
- **"Iterative code" is the wrong mental model for ~80% of these.** Only Targets B and D have a literal compile-time-loop → runtime-loop conversion. The rest are *deduplication* (type erasure, base hoisting, `extern template`, header→source moves). Framing the work as "stop monomorphizing identical bodies" will keep the implementation honest and avoid pessimizing hot paths by replacing inlined templates with slow runtime dispatch where it isn't warranted.
- **Per-frame evaluation paths must stay templated/inlined.** Property `evaluate()` and expression evaluation run per-feature/per-frame. De-templating those trades binary size for runtime cost and can hurt FPS. Restrict loop-ification to cold paths (parsing, transitions, layout setup).
- **Linker ICF already folds some duplication.** Some apparent per-TU duplication is already merged by identical-code-folding at link time, so object-file savings won't translate 1:1 to final-binary savings. Always trust the stripped-binary diff, never the `.o` sizes.

---

## 7. Appendix — how the numbers were derived

- Parsed all 29,097 symbol rows from `bloaty_symbols_file_all.txt`, converted `Ki/Mi` to bytes, excluded the synthetic `TOTAL` row.
- `__LINKEDIT` = 9.55 MiB (debug/symbol tables, stripped from ship build).
- Symbolized code+data = total − `__LINKEDIT` = 5.61 MiB.
- "Template instantiation" = any symbol whose demangled name contains `<` → 1.43 MiB (25.4% of 5.61 MiB).
- Family aggregation by first-match regex over fully-qualified names (see table in §1). Re-run with `scripts/ios-layer-size-bloaty.sh` against `MapLibre.stripped` for ship-accurate figures before committing to targets.
