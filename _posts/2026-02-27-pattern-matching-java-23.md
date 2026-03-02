---
layout: post
title: "Pattern Matching in Java: From instanceof to Primitive Types in Java 23"
date: 2026-02-27 20:00 +0100
categories: [Java, Language Features]
tags: [java, java-23, pattern-matching, instanceof, switch, records, jep-455, jep-441, jep-394]
description: A comprehensive guide to pattern matching in Java, covering the evolution from instanceof patterns in Java 16 to primitive type patterns introduced in Java 23 via JEP 455, with practical examples and Oracle sources.
---

# Pattern Matching in Java: From instanceof to Primitive Types in Java 23

Pattern matching is one of the most significant additions to the Java language in the past decade. It allows developers to test whether a value has a particular structure and extract data from it in a single, concise expression -- replacing verbose chains of `instanceof` checks and explicit casts. With **Java 23**, pattern matching reaches a new level of expressiveness through [JEP 455: Primitive Types in Patterns, instanceof, and switch](https://openjdk.org/jeps/455), which extends pattern matching to work uniformly with all types, including primitives.

This article traces the evolution of pattern matching in Java, explains the mechanics of each feature, and focuses on the new capabilities introduced in Java 23.

## The Evolution of Pattern Matching in Java

Pattern matching did not arrive all at once. It was delivered incrementally across multiple Java releases, each JEP building on the previous one.

| Release | JEP | Feature | Status |
|---------|-----|---------|--------|
| Java 14 | [JEP 305](https://openjdk.org/jeps/305) | Pattern Matching for `instanceof` | Preview |
| Java 16 | [JEP 394](https://openjdk.org/jeps/394) | Pattern Matching for `instanceof` | **Final** |
| Java 17 | [JEP 406](https://openjdk.org/jeps/406) | Pattern Matching for `switch` | Preview |
| Java 21 | [JEP 441](https://openjdk.org/jeps/441) | Pattern Matching for `switch` | **Final** |
| Java 21 | [JEP 440](https://openjdk.org/jeps/440) | Record Patterns | **Final** |
| Java 23 | [JEP 455](https://openjdk.org/jeps/455) | Primitive Types in Patterns, `instanceof`, and `switch` | Preview |

Each step removed friction and made the language more expressive. Java 23's JEP 455 completes the picture by removing the last major limitation: the restriction to reference types only.

## Pattern Matching for instanceof (Java 16)

Before pattern matching, testing and casting an object required two separate steps:

```java
if (obj instanceof String) {
    String s = (String) obj;
    System.out.println(s.length());
}
```

The cast is redundant -- if `instanceof` succeeded, the cast will always succeed too. [JEP 394](https://openjdk.org/jeps/394) merged the test and extraction into a single expression using a **type pattern**:

```java
if (obj instanceof String s) {
    System.out.println(s.length());
}
```

The pattern variable `s` is in scope only where the compiler can prove the pattern matched. This eliminates the possibility of a `ClassCastException` and removes visual clutter.

## Pattern Matching for switch (Java 21)

[JEP 441](https://openjdk.org/jeps/441) extended pattern matching to `switch` expressions and statements. Instead of long `if-else` chains, you can write:

```java
public static double getPerimeter(Shape s) {
    return switch (s) {
        case Rectangle r -> 2 * r.length() + 2 * r.width();
        case Circle c    -> 2 * c.radius() * Math.PI;
        default          -> throw new IllegalArgumentException("Unrecognized shape");
    };
}
```

Pattern matching for `switch` also introduced **guarded patterns** with the `when` keyword and explicit handling of `null` via `case null`:

```java
switch (obj) {
    case String s when s.length() == 1 -> System.out.println("Short: " + s);
    case String s                      -> System.out.println(s);
    case null, default                 -> System.out.println("null or not a string");
}
```

## Record Patterns (Java 21)

[JEP 440](https://openjdk.org/jeps/440) introduced **record patterns** that destructure records directly in pattern contexts. Given a record:

```java
record Point(double x, double y) {}
```

You can decompose it in a single expression:

```java
if (obj instanceof Point(double x, double y)) {
    System.out.println("x=" + x + ", y=" + y);
}
```

Record patterns can be nested, enabling deep structural matching:

```java
record Line(Point start, Point end) {}

if (obj instanceof Line(Point(var x1, var y1), Point(var x2, var y2))) {
    double length = Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
}
```

## Java 23: Primitive Types in Patterns, instanceof, and switch (JEP 455)

With reference types well supported, a significant gap remained: **primitive types** were largely excluded from pattern matching. [JEP 455](https://openjdk.org/jeps/455), delivered as a preview feature in Java 23, eliminates this gap. Its goals, as stated by the JEP authors:

- Enable **uniform data exploration** by allowing type patterns for all types, whether primitive or reference.
- Align type patterns with `instanceof`, and align `instanceof` with **safe casting**.
- Allow pattern matching to use primitive type patterns in both **nested and top-level** contexts.
- Provide constructs that **eliminate the risk of losing information** due to unsafe casts.

### Primitive Type Patterns in switch

Previously, `switch` supported pattern matching only with reference types. You could write `case Integer i` but not `case int i`. JEP 455 lifts this restriction.

Consider an API that returns integer status codes:

```java
switch (x.getStatus()) {
    case 0 -> "okay";
    case 1 -> "warning";
    case 2 -> "error";
    default -> "unknown status: " + x.getStatus();
}
```

The `default` clause loses the matched value -- you need to call `getStatus()` again. With primitive type patterns, you can capture it:

```java
switch (x.getStatus()) {
    case 0     -> "okay";
    case 1     -> "warning";
    case 2     -> "error";
    case int i -> "unknown status: " + i;
}
```

Primitive type patterns work with **guards** too, enabling expressive range-based matching:

```java
switch (x.getYearlyFlights()) {
    case 0                          -> "No flights";
    case 1                          -> "One flight";
    case 2                          -> issueDiscount();
    case int i when i >= 100        -> issueGoldCard();
    case int i                      -> handleFrequency(i);
}
```

### Expanded Primitive Support in switch

Before JEP 455, `switch` only accepted `byte`, `short`, `char`, and `int` (plus their wrappers, `String`, and `enum`). JEP 455 extends `switch` to accept **all primitive types**: `long`, `float`, `double`, and `boolean`.

**Switching on `long`:**

```java
long v = ...;
switch (v) {
    case 1L              -> handleOne();
    case 2L              -> handleTwo();
    case 10_000_000_000L -> handleTenBillion();
    case long x          -> handleOther(x);
}
```

**Switching on `boolean`:**

A `boolean` switch is a useful alternative to the ternary operator when you need statements, not just expressions:

```java
startProcessing(OrderStatus.NEW, switch (user.isLoggedIn()) {
    case true  -> user.id();
    case false -> { log("Unrecognized user"); yield -1; }
});
```

A `switch` listing both `true` and `false` is considered exhaustive.

**Switching on `float` and `double`:**

```java
float v = ...;
switch (v) {
    case 0f                              -> 5f;
    case float x when x == 1f           -> 6f + x;
    case float x                         -> 7f + x;
}
```

Constants in `case` labels must match the selector type exactly. For example, if the selector is a `float`, the constant must be a `float` literal -- writing `0` instead of `0f` is a compile-time error. This prevents silent lossy conversions.

### Primitive Type Patterns in instanceof

[JEP 455](https://openjdk.org/jeps/455) also extends `instanceof` to work with primitive types. The operator answers the question: **can this value be converted exactly to this type without loss of information?**

This replaces manual range checks that Java developers have written by hand for decades:

```java
// Before JEP 455: manual range check
if (i >= -128 && i <= 127) {
    byte b = (byte) i;
    // ... use b ...
}

// With JEP 455: safe and concise
if (i instanceof byte b) {
    // ... use b, guaranteed no loss of information ...
}
```

The same applies to detecting precision loss when converting `int` to `float`:

```java
int population = getPopulation();
float pop = population;  // silent potential loss of information!

// Safe alternative:
if (getPopulation() instanceof float pop) {
    // ... pop accurately represents the value ...
}
```

Here is a summary of how `instanceof` behaves with primitive types, taken directly from the [JEP 455 specification](https://openjdk.org/jeps/455):

```java
byte b = 42;
b instanceof int;         // true  (unconditionally exact)

int i = 42;
i instanceof byte;        // true  (exact: 42 fits in a byte)

int i = 1000;
i instanceof byte;        // false (not exact: 1000 does not fit)

int i = 16_777_217;       // 2^24 + 1
i instanceof float;       // false (not exact: precision loss)
i instanceof double;      // true  (unconditionally exact)

double d = 1000.0d;
d instanceof byte;        // false
d instanceof int;         // true  (exact)
d instanceof float;       // true  (exact)
```

The key concept is **exact conversion**: a conversion that loses no information. The compiler knows at compile time which conversions are **unconditionally exact** (always safe, like `byte` to `int`) and which require a **run-time check** (like `int` to `byte`, where the outcome depends on the actual value).

### Improved Primitive Types in Record Patterns

Before JEP 455, decomposing a record with primitive components was rigid. Consider a JSON representation using records:

```java
sealed interface JsonValue {
    record JsonString(String s) implements JsonValue {}
    record JsonNumber(double d) implements JsonValue {}
    record JsonObject(Map<String, JsonValue> map) implements JsonValue {}
}
```

`JsonNumber` stores its value as `double` for maximum flexibility. Creating a `JsonNumber` with an `int` works thanks to widening:

```java
var json = new JsonObject(Map.of(
    "name", new JsonString("John"),
    "age",  new JsonNumber(30)     // int 30 widened to double
));
```

But decomposing required matching the exact declared type, forcing a manual cast:

```java
// Before JEP 455
if (json instanceof JsonObject(var map)
    && map.get("age") instanceof JsonNumber(double a)) {
    int age = (int) a;  // manual, potentially lossy cast
}
```

With JEP 455, the record pattern can narrow the type automatically and safely:

```java
// With JEP 455
if (json instanceof JsonObject(var map)
    && map.get("age") instanceof JsonNumber(int age)) {
    // age is already an int -- safe, no manual cast needed
    // pattern only matches if the double value fits exactly in an int
}
```

If the `double` component cannot be safely narrowed to `int` (e.g., the value is `3.14` or `3_000_000_000.0`), the pattern simply does not match and the program handles the value in a different branch.

### Safety of Conversions

JEP 455 formalizes the concept of **exact conversions** between primitive types. A conversion is exact if no loss of information occurs. Whether a conversion is exact depends on both the types involved and the actual value at run time.

- **Unconditionally exact**: Known at compile time to never lose information for any value. Examples: `byte` to `int`, `int` to `long`, `float` to `double`.
- **Conditionally exact**: Requires a run-time check. Examples: `int` to `byte` (depends on magnitude), `int` to `float` (depends on precision), `long` to `int`.

This concept underpins both `instanceof` and pattern matching. When you write `i instanceof byte b`, the compiler emits a run-time check that succeeds only if the conversion from the type of `i` to `byte` is exact for the current value.

## Putting It All Together

Here is an example that combines sealed interfaces, record patterns, and primitive type patterns to build a simple expression evaluator:

```java
sealed interface Expr {
    record Num(double value) implements Expr {}
    record Add(Expr left, Expr right) implements Expr {}
    record Mul(Expr left, Expr right) implements Expr {}
    record Neg(Expr operand) implements Expr {}
}

double evaluate(Expr expr) {
    return switch (expr) {
        case Num(double v)         -> v;
        case Add(var left, var right) -> evaluate(left) + evaluate(right);
        case Mul(var left, var right) -> evaluate(left) * evaluate(right);
        case Neg(var operand)         -> -evaluate(operand);
    };
}

String classify(Expr expr) {
    return switch (evaluate(expr)) {
        case 0d                              -> "zero";
        case double d when d > 0 && d < 1    -> "small positive fraction";
        case double d when d instanceof int i -> "whole number: " + i;
        case double d                         -> "other: " + d;
    };
}
```

The sealed `Expr` hierarchy ensures the `switch` in `evaluate` is exhaustive without a `default` branch. The `classify` method switches on a `double` (new in Java 23) and uses a guard with a nested `instanceof` to detect whole numbers.

## Preview Status and How to Enable

JEP 455 is a **preview language feature** in Java 23. To compile and run code using it, you must pass the `--enable-preview` flag:

```bash
javac --enable-preview --release 23 MyApp.java
java  --enable-preview MyApp
```

The feature has continued through additional preview rounds in subsequent releases ([JEP 488](https://openjdk.org/jeps/488) in Java 24, [JEP 530](https://openjdk.org/jeps/530) as a fourth preview), indicating the design is still being refined based on community feedback before becoming a permanent feature.

## Summary

Pattern matching in Java has evolved from a single convenience in `instanceof` (Java 16) to a powerful, composable system that works across `switch`, records, sealed types, and -- as of Java 23 -- **all primitive types**. JEP 455 fills the last major gap by enabling:

- **Primitive type patterns** in `switch`, `instanceof`, and record patterns.
- **Expanded `switch`** to accept `long`, `float`, `double`, and `boolean`.
- **Safe conversions** via the formalized concept of exact conversions, eliminating silent information loss.

Together with sealed classes ([JEP 409](https://openjdk.org/jeps/409)) and record patterns ([JEP 440](https://openjdk.org/jeps/440)), primitive type patterns make Java's pattern matching system one of the most comprehensive in any mainstream language -- providing exhaustiveness checking, null safety, and type safety in a single, readable syntax.

## Sources

- [JEP 455: Primitive Types in Patterns, instanceof, and switch (Preview)](https://openjdk.org/jeps/455) -- OpenJDK
- [JEP 441: Pattern Matching for switch](https://openjdk.org/jeps/441) -- OpenJDK
- [JEP 440: Record Patterns](https://openjdk.org/jeps/440) -- OpenJDK
- [JEP 394: Pattern Matching for instanceof](https://openjdk.org/jeps/394) -- OpenJDK
- [Pattern Matching -- Java SE 23 Language Guide](https://docs.oracle.com/en/java/javase/23/language/pattern-matching.html) -- Oracle
- [Pattern Matching with switch -- Java SE 23 Language Guide](https://docs.oracle.com/en/java/javase/23/language/pattern-matching-switch.html) -- Oracle
- [Java Language Changes by Release -- Java SE 23](https://docs.oracle.com/en/java/javase/23/language/java-language-changes-release.html) -- Oracle
