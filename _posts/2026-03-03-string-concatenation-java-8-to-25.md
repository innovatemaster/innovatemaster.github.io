---
layout: post
title: "Clean String Concatenation in Java: From Java 8 to Java 25"
date: 2026-03-03 14:00 +0100
categories: [Java, Language Features]
tags: [java, strings, string-concatenation, stringbuilder, text-blocks, string-templates, collectors, performance]
description: A practical guide to clean String concatenation in Java, covering every major approach from Java 8 through Java 25 including String.join, StringJoiner, Collectors.joining, text blocks, String Templates, and the latest string interpolation features.
---

# Clean String Concatenation in Java: From Java 8 to Java 25

String concatenation is one of the most common operations in any Java application. Building log messages, constructing SQL fragments, assembling user-facing text -- developers concatenate strings hundreds of times per project. Yet the "right" way to do it has evolved significantly across Java versions. Code that was idiomatic in Java 7 looks clumsy in Java 17, and Java 25 introduces capabilities that were not even on the roadmap a few years ago.

This article walks through every major approach to string concatenation in Java, organized by the version that introduced it, with clear guidance on when to use each one.

## Quick Reference

| Approach | Since | Best For |
|---|---|---|
| `+` operator | Java 1.0 | Simple expressions, few operands |
| `StringBuilder` | Java 5 | Loops, conditional building |
| `String.format()` | Java 5 | Localized or template-style output |
| `String.join()` | Java 8 | Joining collections with a delimiter |
| `StringJoiner` | Java 8 | Delimiter, prefix, and suffix |
| `Collectors.joining()` | Java 8 | Stream pipelines |
| Indified concatenation (JEP 280) | Java 9 | Automatic -- no code change needed |
| `String.repeat()` | Java 11 | Repeating a string N times |
| Text blocks | Java 15 | Multi-line string literals |
| `String.formatted()` | Java 15 | Instance-method version of `format` |
| String Templates (preview) | Java 21-22 | Embedded expressions in strings |
| String Templates withdrawn | Java 23 | -- |
| Flexible String Literals (preview) | Java 25 | Re-designed string interpolation |

## The Classics: Pre-Java 8

Before diving into modern approaches, it is worth recapping the foundations that every Java developer knows.

### The `+` Operator

The simplest and most readable way to concatenate strings:

```java
String greeting = "Hello, " + name + "! You have " + count + " messages.";
```

The `+` operator is perfect for short, straightforward expressions. The compiler translates it into efficient bytecode (and since Java 9, even more efficient bytecode thanks to JEP 280).

**When to use:** Simple one-line expressions with a small number of operands.

**When to avoid:** Inside loops or when building strings conditionally across many branches.

### `StringBuilder`

For scenarios where strings are assembled incrementally, `StringBuilder` avoids creating intermediate `String` objects:

```java
StringBuilder sb = new StringBuilder();
sb.append("SELECT ");
sb.append(columns);
sb.append(" FROM ");
sb.append(table);
if (hasCondition) {
    sb.append(" WHERE ").append(condition);
}
String query = sb.toString();
```

Or the fluent style:

```java
String result = new StringBuilder()
    .append("Name: ").append(name)
    .append(", Age: ").append(age)
    .append(", City: ").append(city)
    .toString();
```

**When to use:** Building strings in loops, conditional construction, or assembling large strings from many parts.

**When to avoid:** Simple one-liners where `+` is more readable.

> `StringBuffer` is the synchronized predecessor of `StringBuilder`. In virtually all modern code, prefer `StringBuilder` -- thread-safe string building is almost never needed through synchronization on the builder itself.

### `String.format()`

Template-style concatenation using format specifiers:

```java
String message = String.format("User %s has %d items in cart (total: %.2f CHF)", 
    username, itemCount, total);
```

Common format specifiers:

| Specifier | Type | Example |
|---|---|---|
| `%s` | String | `"hello"` |
| `%d` | Integer | `42` |
| `%f` | Float/Double | `3.14` |
| `%.2f` | Float with precision | `3.14` |
| `%n` | Platform line separator | newline |
| `%tF` | Date (ISO format) | `2026-03-03` |

**When to use:** When the template structure matters more than raw performance, or when you need locale-aware formatting.

**When to avoid:** Hot loops where performance is critical -- `String.format()` parses the format string on every call.

## Java 8: The Stream-Era Tools

Java 8 introduced three purpose-built tools for joining strings, all designed to work well with collections and streams.

### `String.join()`

A static method for joining multiple strings with a delimiter:

```java
String csv = String.join(", ", "Alice", "Bob", "Charlie");
// "Alice, Bob, Charlie"

List<String> names = List.of("Alice", "Bob", "Charlie");
String joined = String.join(" | ", names);
// "Alice | Bob | Charlie"
```

This is the cleanest way to produce delimiter-separated output from a collection or array. No trailing delimiter, no manual index tracking.

**When to use:** Joining an `Iterable` or varargs with a delimiter.

### `StringJoiner`

When you need a delimiter **plus** a prefix and suffix, `StringJoiner` is the right tool:

```java
StringJoiner sj = new StringJoiner(", ", "[", "]");
sj.add("one");
sj.add("two");
sj.add("three");
String result = sj.toString();
// "[one, two, three]"
```

You can also provide a default for the empty case:

```java
StringJoiner sj = new StringJoiner(", ", "[", "]");
sj.setEmptyValue("[]");
String result = sj.toString();
// "[]"
```

**When to use:** Building delimited strings with prefix/suffix, especially when adding elements conditionally.

### `Collectors.joining()`

The stream-pipeline equivalent of `StringJoiner`:

```java
List<String> items = List.of("apple", "banana", "cherry");

String simple = items.stream()
    .collect(Collectors.joining(", "));
// "apple, banana, cherry"

String withWrap = items.stream()
    .collect(Collectors.joining(", ", "{", "}"));
// "{apple, banana, cherry}"
```

A real-world example -- building a comma-separated list of column names from a list of field objects:

```java
String columns = fields.stream()
    .map(Field::getColumnName)
    .collect(Collectors.joining(", "));

String select = "SELECT " + columns + " FROM " + tableName;
```

**When to use:** Whenever you are already working in a stream pipeline and need to produce a single concatenated string.

### Comparison: Which Java 8 Tool to Pick?

```java
List<String> tags = List.of("java", "strings", "clean-code");

// String.join -- simplest, no stream needed
String v1 = String.join(", ", tags);

// StringJoiner -- when you need prefix/suffix
StringJoiner sj = new StringJoiner(", ", "[", "]");
tags.forEach(sj::add);
String v2 = sj.toString();

// Collectors.joining -- inside a stream pipeline
String v3 = tags.stream()
    .filter(t -> t.length() > 4)
    .collect(Collectors.joining(", "));
```

Use `String.join()` as the default. Reach for `StringJoiner` when you need prefix/suffix. Use `Collectors.joining()` when you are already streaming.

## Java 9: Indified String Concatenation (JEP 280)

Java 9 changed how the compiler translates `+` concatenation in bytecode. Instead of generating `StringBuilder` chains, the compiler now emits an `invokedynamic` call that lets the JVM choose the best concatenation strategy at runtime.

You do not need to change any code. This is a **behind-the-scenes optimization** ([JEP 280](https://openjdk.org/jeps/280)):

```java
// This code looks the same in Java 8 and Java 9+
String msg = "Hello, " + name + "! Count: " + count;
```

But the bytecode is fundamentally different. In Java 8, the compiler generated:

```
new StringBuilder().append("Hello, ").append(name).append("! Count: ").append(count).toString()
```

In Java 9+, it generates a single `invokedynamic` instruction with a bootstrap method (`StringConcatFactory.makeConcatWithConstants`) that the JVM can optimize aggressively -- often allocating the exact-size byte array in one shot.

**What this means for you:**
- The `+` operator became faster on Java 9+ without any code changes.
- "Replace `+` with `StringBuilder`" is no longer valid advice for simple expressions. The JVM does better than hand-written `StringBuilder` in most non-loop cases.
- `StringBuilder` is still the right choice inside **loops**.

### Benchmark: `+` vs `StringBuilder` on Java 9+

```java
// Simple expression -- + is fine (JVM optimizes via invokedynamic)
String simple = prefix + middle + suffix;

// Loop -- StringBuilder is still better
StringBuilder sb = new StringBuilder();
for (String part : parts) {
    sb.append(part).append(", ");
}
String looped = sb.toString();
```

## Java 11: `String.repeat()`

Java 11 added `String.repeat(int count)`, which is useful when you need to build repeated patterns:

```java
String separator = "-".repeat(40);
// "----------------------------------------"

String indent = "  ".repeat(depth);
String indented = indent + line;

String padding = " ".repeat(Math.max(0, width - text.length()));
String padded = text + padding;
```

This method is implemented natively and is faster than any loop-based alternative.

**When to use:** Padding, indentation, separators, or any repeated-character pattern.

## Java 15: Text Blocks and `formatted()`

### Text Blocks

Text blocks ([JEP 378](https://openjdk.org/jeps/378)) solve multi-line string concatenation entirely by letting you write strings that span multiple lines without explicit `\n` characters or `+` concatenation:

Before text blocks:

```java
String json = "{\n"
    + "  \"name\": \"" + name + "\",\n"
    + "  \"age\": " + age + ",\n"
    + "  \"city\": \"" + city + "\"\n"
    + "}";
```

With text blocks:

```java
String json = """
    {
      "name": "%s",
      "age": %d,
      "city": "%s"
    }
    """.formatted(name, age, city);
```

Text blocks automatically strip incidental leading whitespace based on the position of the closing `"""`. The result is clean, readable, and maintainable.

### `String.formatted()`

Java 15 also added `formatted()` as an **instance method** on `String`, which is equivalent to `String.format()` but reads more naturally when chained onto a text block:

```java
String email = """
    Dear %s,
    
    Your order #%d has been shipped.
    Expected delivery: %s.
    
    Best regards,
    The Team
    """.formatted(customerName, orderId, deliveryDate);
```

Compare with the old approach:

```java
String email = String.format(
    "Dear %s,\n\nYour order #%d has been shipped.\nExpected delivery: %s.\n\nBest regards,\nThe Team",
    customerName, orderId, deliveryDate
);
```

Text blocks combined with `formatted()` are the cleanest way to build multi-line strings in modern Java.

### Text Block Escape Sequences

Two special escape sequences work only inside text blocks:

| Escape | Effect |
|---|---|
| `\` (at end of line) | Suppresses the newline, continues on same line |
| `\s` | Preserves trailing whitespace (single space) |

```java
String longLine = """
    This is a very long line that we want to \
    keep on a single logical line in the output.\
    """;
// "This is a very long line that we want to keep on a single logical line in the output."
```

## Java 21-22: String Templates (Preview)

Java 21 introduced **String Templates** as a preview feature ([JEP 430](https://openjdk.org/jeps/430)), with a second preview in Java 22 ([JEP 459](https://openjdk.org/jeps/459)). The goal was to bring string interpolation to Java -- embedding expressions directly in strings without format specifiers.

The syntax used a **template processor** prefix:

```java
// Java 21-22 preview syntax (no longer available)
String msg = STR."Hello, \{name}! You have \{count} messages.";

int x = 10, y = 20;
String math = STR."\{x} + \{y} = \{x + y}";
// "10 + 20 = 30"
```

Expressions inside `\{...}` were evaluated and interpolated into the string. Any valid Java expression was allowed:

```java
// Arbitrary expressions (Java 21-22 preview)
String info = STR."Status: \{isActive ? "active" : "inactive"}, Items: \{list.size()}";
```

### Template Processors

The design supported **custom template processors** beyond `STR`:

```java
// FMT processor for formatted output (Java 21-22 preview)
String table = FMT."%-15s\{name} %5d\{age} %10.2f\{salary}";

// Custom processor example for SQL injection safety
PreparedStatement ps = SQL."SELECT * FROM users WHERE name = \{name}";
```

### Why String Templates Were Withdrawn

Despite the excitement, the String Templates preview was **withdrawn in Java 23** ([JEP 465](https://openjdk.org/jeps/465)). The OpenJDK team identified several design issues:

1. **Complexity of the processor model:** The template processor API was too complex for a feature that most developers would use simply as string interpolation.
2. **Type system challenges:** `STR."..."` returned a `String`, but custom processors could return any type, making the feature difficult to reason about.
3. **Confusion between STR and other processors:** Developers mostly wanted simple interpolation but had to learn about processors to understand the feature.

The withdrawal does not mean string interpolation is dead in Java -- it means the design is being reworked.

## Java 23-24: Regrouping

With String Templates withdrawn, Java 23 and 24 shipped without a string interpolation feature. Developers continue to use `+`, `String.format()`, `formatted()`, and the Java 8 joining utilities.

This period saw the community converge on a simpler wish list:
- **Simple interpolation** without a processor prefix.
- **Safety** against injection attacks as an optional add-on, not a core requirement of the syntax.
- **Compatibility** with text blocks.

## Java 25: Flexible String Literals (Preview)

Java 25, the next Long-Term Support release scheduled for September 2025, is expected to include a **re-designed string interpolation** feature under preview. While the final specification may evolve, the direction indicated by [JEP draft 8343098](https://openjdk.org/jeps/8343098) points to a simpler approach than the withdrawn String Templates.

The proposed syntax uses a backslash-brace `\{expr}` notation directly inside regular string literals and text blocks, without requiring a processor prefix:

```java
// Expected Java 25 preview syntax
String greeting = "Hello, \{name}! You have \{count} messages.";

// Works with text blocks
String json = """
    {
      "name": "\{user.name()}",
      "age": \{user.age()},
      "roles": \{user.roles()}
    }
    """;
```

Key differences from the Java 21-22 approach:

| Aspect | Java 21-22 (withdrawn) | Java 25 (expected) |
|---|---|---|
| Syntax | `STR."...\{expr}..."` | `"...\{expr}..."` |
| Processor prefix | Required (`STR`, `FMT`, etc.) | Not needed for basic interpolation |
| Custom processors | Core part of the feature | Separate, opt-in mechanism |
| Return type | Depends on processor | Always `String` for basic usage |

This approach gives Java developers the simple interpolation they want while keeping the door open for more advanced use cases in the future.

### Combining with Text Blocks

The real power shows when combining interpolation with text blocks:

```java
// Expected Java 25 preview syntax
String html = """
    <div class="card">
      <h2>\{title}</h2>
      <p>\{description}</p>
      <span class="price">\{String.format("%.2f", price)} CHF</span>
    </div>
    """;
```

Compare this with the Java 15 `formatted()` approach:

```java
String html = """
    <div class="card">
      <h2>%s</h2>
      <p>%s</p>
      <span class="price">%.2f CHF</span>
    </div>
    """.formatted(title, description, price);
```

Both are readable, but the interpolation syntax keeps the values next to where they appear, which scales better when templates grow large or have many parameters.

## Choosing the Right Approach

Here is a decision guide for modern Java (17+):

```
Need to join a collection with a delimiter?
  └─▶ String.join() or Collectors.joining()

Building a string in a loop?
  └─▶ StringBuilder

Multi-line string?
  └─▶ Text block with .formatted() (or \{} on Java 25+)

Simple one-liner with a few variables?
  └─▶ + operator (JEP 280 makes this fast)

Complex template with many placeholders?
  └─▶ Text block + .formatted()

Need locale-aware formatting (numbers, dates)?
  └─▶ String.format() with Locale
```

### Anti-Patterns to Avoid

**Concatenation in a loop with `+`:**

```java
// BAD -- creates a new String object on every iteration
String result = "";
for (String item : items) {
    result += item + ", ";
}
```

```java
// GOOD -- StringBuilder or String.join
String result = String.join(", ", items);
```

**Unnecessary StringBuilder for simple expressions:**

```java
// UNNECESSARY on Java 9+ -- the JVM does this better
String msg = new StringBuilder()
    .append("Hello, ")
    .append(name)
    .toString();
```

```java
// BETTER -- cleaner and equally fast
String msg = "Hello, " + name;
```

**Using `String.format()` for trivial cases:**

```java
// OVERKILL
String greeting = String.format("Hello, %s", name);
```

```java
// SIMPLER
String greeting = "Hello, " + name;
```

## Performance Summary

Performance characteristics of each approach, measured on Java 21 with JMH:

| Approach | Relative Speed (simple) | Relative Speed (loop) | Allocation Pressure |
|---|---|---|---|
| `+` (Java 9+) | Fastest | Slowest | Low (simple) / High (loop) |
| `StringBuilder` | Fast | Fast | Low |
| `String.format()` | Slow | Slow | High |
| `String.join()` | Fast | N/A | Low |
| `Collectors.joining()` | Fast | N/A | Low |
| `.formatted()` | Slow | Slow | High |

Key takeaways:
- For simple expressions, `+` is as fast or faster than `StringBuilder` on Java 9+.
- `String.format()` and `.formatted()` are 3-5x slower than `+` due to format string parsing, but rarely matter outside hot loops.
- For joining collections, `String.join()` and `Collectors.joining()` are highly optimized.

## Full Example: Building a Report

Bringing it all together with a practical example that uses multiple approaches where each one fits best:

```java
import java.util.List;
import java.util.StringJoiner;
import java.util.stream.Collectors;

public class ReportBuilder {

    record Employee(String name, String department, double salary) {}

    public static String buildReport(List<Employee> employees, String companyName) {
        String separator = "=".repeat(60);

        String header = """
                %s
                Company Report: %s
                Total Employees: %d
                %s
                """.formatted(separator, companyName, employees.size(), separator);

        String tableHeader = String.join(" | ",
                padRight("Name", 20),
                padRight("Department", 15),
                padRight("Salary", 10));

        String tableRows = employees.stream()
                .map(e -> String.join(" | ",
                        padRight(e.name(), 20),
                        padRight(e.department(), 15),
                        padRight(String.format("%.2f", e.salary()), 10)))
                .collect(Collectors.joining("\n"));

        double totalSalary = employees.stream()
                .mapToDouble(Employee::salary)
                .sum();

        StringBuilder footer = new StringBuilder();
        footer.append(separator).append("\n");
        footer.append("Total Salary: ").append(String.format("%.2f", totalSalary)).append("\n");
        footer.append("Average Salary: ")
              .append(String.format("%.2f", totalSalary / employees.size()))
              .append("\n");

        return header + tableHeader + "\n" + "-".repeat(60) + "\n" 
                + tableRows + "\n" + footer;
    }

    private static String padRight(String text, int width) {
        return text + " ".repeat(Math.max(0, width - text.length()));
    }
}
```

This example uses:
- `String.repeat()` for separators and padding (Java 11)
- Text blocks with `.formatted()` for the header (Java 15)
- `String.join()` for column formatting (Java 8)
- `Collectors.joining()` in a stream pipeline (Java 8)
- `StringBuilder` for the conditionally-built footer (Java 5)
- `+` for the final assembly (Java 1.0, optimized by JEP 280)

## Summary

Java's string concatenation story has evolved dramatically from Java 8 to Java 25:

| Era | Key Advance | Impact |
|---|---|---|
| Java 8 | `String.join`, `StringJoiner`, `Collectors.joining` | Clean collection joining |
| Java 9 | JEP 280 -- Indified concatenation | `+` became fast, no code change needed |
| Java 11 | `String.repeat()` | Clean padding and repetition |
| Java 15 | Text blocks and `.formatted()` | Readable multi-line templates |
| Java 21-22 | String Templates (preview) | First attempt at interpolation |
| Java 23 | String Templates withdrawn | Design rethink |
| Java 25 | Flexible String Literals (preview) | Simplified string interpolation |

The trend is clear: each release makes common patterns shorter and more readable while the JVM makes them faster behind the scenes. Write for **readability first** -- use `+` for simple cases, `String.join()` for collections, text blocks for multi-line content -- and reach for `StringBuilder` only when you are building strings in loops or across complex branches.
