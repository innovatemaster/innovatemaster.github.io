---
layout: post
title: "Sorting Algorithms in Java: From Bubble Sort to TimSort"
date: 2026-03-02 10:00 +0100
categories: [Java, Algorithms]
tags: [java, algorithms, sorting, data-structures, big-o, arrays, collections]
description: A practical guide to sorting algorithms implemented in Java, covering Bubble Sort, Selection Sort, Insertion Sort, Merge Sort, Quick Sort, Heap Sort, and Java's built-in sorting facilities, with complexity analysis and full code examples.
---

# Sorting Algorithms in Java: From Bubble Sort to TimSort

Sorting is one of the most fundamental operations in computer science. Whether you are ranking search results, organizing database records, or preparing data for binary search, an efficient sort is often the first step. Understanding how sorting algorithms work -- their trade-offs, their complexity, and when to choose one over another -- is essential knowledge for every developer.

This article walks through the most important sorting algorithms, implements each one in Java, analyzes their time and space complexity, and explains when Java's built-in sorting is the right choice.

## Complexity at a Glance

| Algorithm      | Best Case   | Average Case | Worst Case  | Space    | Stable |
|----------------|-------------|--------------|-------------|----------|--------|
| Bubble Sort    | O(n)        | O(n²)        | O(n²)       | O(1)     | Yes    |
| Selection Sort | O(n²)       | O(n²)        | O(n²)       | O(1)     | No     |
| Insertion Sort | O(n)        | O(n²)        | O(n²)       | O(1)     | Yes    |
| Merge Sort     | O(n log n)  | O(n log n)   | O(n log n)  | O(n)     | Yes    |
| Quick Sort     | O(n log n)  | O(n log n)   | O(n²)       | O(log n) | No     |
| Heap Sort      | O(n log n)  | O(n log n)   | O(n log n)  | O(1)     | No     |
| TimSort        | O(n)        | O(n log n)   | O(n log n)  | O(n)     | Yes    |

**Stable** means equal elements preserve their original relative order after sorting. This matters when you sort by multiple criteria -- for example, sorting a list of employees by department and then by name within each department.

## Bubble Sort

Bubble Sort repeatedly steps through the array, compares adjacent elements, and swaps them if they are in the wrong order. The largest unsorted element "bubbles up" to its correct position at the end of each pass.

```java
public static void bubbleSort(int[] arr) {
    int n = arr.length;
    for (int i = 0; i < n - 1; i++) {
        boolean swapped = false;
        for (int j = 0; j < n - 1 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                int temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
                swapped = true;
            }
        }
        if (!swapped) break;
    }
}
```

The `swapped` flag is an optimization: if a full pass completes without any swaps, the array is already sorted and the algorithm terminates early. This gives Bubble Sort its O(n) best case on already-sorted input.

Despite its simplicity, Bubble Sort is rarely used in practice because its O(n²) average and worst cases make it impractical for anything beyond small datasets or educational purposes.

## Selection Sort

Selection Sort divides the array into a sorted prefix and an unsorted suffix. In each iteration, it finds the minimum element in the unsorted portion and moves it to the end of the sorted portion.

```java
public static void selectionSort(int[] arr) {
    int n = arr.length;
    for (int i = 0; i < n - 1; i++) {
        int minIdx = i;
        for (int j = i + 1; j < n; j++) {
            if (arr[j] < arr[minIdx]) {
                minIdx = j;
            }
        }
        int temp = arr[minIdx];
        arr[minIdx] = arr[i];
        arr[i] = temp;
    }
}
```

Selection Sort always performs O(n²) comparisons regardless of the initial order, making it uniformly slow. However, it performs at most O(n) swaps, which can be an advantage when write operations are expensive (e.g., writing to flash memory).

Selection Sort is **not stable** because the swap can move an element past its equal counterpart. For example, sorting `[5a, 3, 5b]` would swap `5a` with `3`, producing `[3, 5a, 5b]` -- but other inputs can reverse equal elements.

## Insertion Sort

Insertion Sort builds the sorted array one element at a time by picking the next unsorted element and inserting it into its correct position within the already-sorted prefix.

```java
public static void insertionSort(int[] arr) {
    for (int i = 1; i < arr.length; i++) {
        int key = arr[i];
        int j = i - 1;
        while (j >= 0 && arr[j] > key) {
            arr[j + 1] = arr[j];
            j--;
        }
        arr[j + 1] = key;
    }
}
```

Insertion Sort is the algorithm of choice for **small arrays** and **nearly sorted data**:

- On already-sorted input it runs in O(n) -- the inner loop never executes.
- Its low overhead and good cache behavior make it faster than O(n log n) algorithms for arrays smaller than about 20-50 elements.
- It is **stable** and **in-place**.

This is why Java's built-in `Arrays.sort` switches to Insertion Sort for small partitions during its divide-and-conquer phase.

## Merge Sort

Merge Sort is a classic divide-and-conquer algorithm. It splits the array in half, recursively sorts each half, and then merges the two sorted halves into a single sorted array.

```java
public static void mergeSort(int[] arr, int left, int right) {
    if (left >= right) return;

    int mid = left + (right - left) / 2;
    mergeSort(arr, left, mid);
    mergeSort(arr, mid + 1, right);
    merge(arr, left, mid, right);
}

private static void merge(int[] arr, int left, int mid, int right) {
    int[] temp = new int[right - left + 1];
    int i = left, j = mid + 1, k = 0;

    while (i <= mid && j <= right) {
        if (arr[i] <= arr[j]) {
            temp[k++] = arr[i++];
        } else {
            temp[k++] = arr[j++];
        }
    }
    while (i <= mid) temp[k++] = arr[i++];
    while (j <= right) temp[k++] = arr[j++];

    System.arraycopy(temp, 0, arr, left, temp.length);
}
```

To sort a full array: `mergeSort(arr, 0, arr.length - 1)`.

Merge Sort guarantees O(n log n) in **all cases** -- best, average, and worst. The price is O(n) additional memory for the temporary array used during merging.

The `<=` comparison in the merge step (`arr[i] <= arr[j]`) is what makes Merge Sort **stable**: equal elements from the left half are placed before equal elements from the right half, preserving their original order.

Merge Sort is the foundation of Java's `Collections.sort()` (via TimSort) and is the preferred algorithm when stability and predictable performance matter more than memory usage.

## Quick Sort

Quick Sort is another divide-and-conquer algorithm. It selects a **pivot** element, partitions the array so that all elements less than the pivot come before it and all elements greater come after it, and then recursively sorts the two partitions.

```java
public static void quickSort(int[] arr, int low, int high) {
    if (low >= high) return;

    int pivotIndex = partition(arr, low, high);
    quickSort(arr, low, pivotIndex - 1);
    quickSort(arr, pivotIndex + 1, high);
}

private static int partition(int[] arr, int low, int high) {
    int pivot = arr[high];
    int i = low - 1;
    for (int j = low; j < high; j++) {
        if (arr[j] <= pivot) {
            i++;
            int temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }
    int temp = arr[i + 1];
    arr[i + 1] = arr[high];
    arr[high] = temp;
    return i + 1;
}
```

To sort a full array: `quickSort(arr, 0, arr.length - 1)`.

This implementation uses the **Lomuto partition scheme** with the last element as the pivot. While simple, it degrades to O(n²) when the input is already sorted or nearly sorted, because every partition produces one empty side and one side of size n-1.

### Improving Pivot Selection

The **median-of-three** strategy picks the median of the first, middle, and last elements as the pivot. This avoids the worst case for sorted and reverse-sorted input:

```java
private static int medianOfThree(int[] arr, int low, int high) {
    int mid = low + (high - low) / 2;
    if (arr[low] > arr[mid]) swap(arr, low, mid);
    if (arr[low] > arr[high]) swap(arr, low, high);
    if (arr[mid] > arr[high]) swap(arr, mid, high);
    swap(arr, mid, high);
    return partition(arr, low, high);
}

private static void swap(int[] arr, int i, int j) {
    int temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
}
```

Quick Sort is **not stable** -- the partition step can rearrange equal elements. Despite its O(n²) worst case, Quick Sort is often the fastest general-purpose sorting algorithm in practice because:

- It sorts **in-place** with O(log n) stack space (for the recursion).
- It has excellent **cache locality** -- it accesses elements sequentially within each partition.
- The constant factors in its O(n log n) average case are very small.

Java's `Arrays.sort` for primitive arrays uses Dual-Pivot Quick Sort, an optimized variant that partitions the array into three parts using two pivots.

## Heap Sort

Heap Sort leverages the **binary heap** data structure. It first builds a max-heap from the array, then repeatedly extracts the maximum element and places it at the end.

```java
public static void heapSort(int[] arr) {
    int n = arr.length;

    for (int i = n / 2 - 1; i >= 0; i--) {
        heapify(arr, n, i);
    }

    for (int i = n - 1; i > 0; i--) {
        int temp = arr[0];
        arr[0] = arr[i];
        arr[i] = temp;
        heapify(arr, i, 0);
    }
}

private static void heapify(int[] arr, int size, int root) {
    int largest = root;
    int left = 2 * root + 1;
    int right = 2 * root + 2;

    if (left < size && arr[left] > arr[largest]) largest = left;
    if (right < size && arr[right] > arr[largest]) largest = right;

    if (largest != root) {
        int temp = arr[root];
        arr[root] = arr[largest];
        arr[largest] = temp;
        heapify(arr, size, largest);
    }
}
```

Heap Sort delivers O(n log n) in all cases and uses only O(1) extra space, making it the best choice when you need **guaranteed performance with minimal memory**. However, it is not stable and has poor cache locality compared to Quick Sort (it accesses array elements in a scattered, tree-like pattern), so it is typically slower in practice despite the same asymptotic complexity.

## Counting Sort

For integer data within a known, limited range, **Counting Sort** achieves O(n + k) time where k is the range of values. It counts occurrences of each value and uses those counts to place elements directly into their sorted positions.

```java
public static void countingSort(int[] arr) {
    if (arr.length == 0) return;

    int max = Arrays.stream(arr).max().getAsInt();
    int min = Arrays.stream(arr).min().getAsInt();
    int range = max - min + 1;

    int[] count = new int[range];
    int[] output = new int[arr.length];

    for (int value : arr) {
        count[value - min]++;
    }

    for (int i = 1; i < range; i++) {
        count[i] += count[i - 1];
    }

    for (int i = arr.length - 1; i >= 0; i--) {
        output[count[arr[i] - min] - 1] = arr[i];
        count[arr[i] - min]--;
    }

    System.arraycopy(output, 0, arr, 0, arr.length);
}
```

Counting Sort is **stable** and extremely fast when the range k is not significantly larger than n. It is commonly used as a subroutine in Radix Sort.

## Java's Built-in Sorting

Java provides highly optimized sorting through the `java.util.Arrays` and `java.util.Collections` classes. Understanding what happens under the hood helps you make informed decisions.

### Arrays.sort for Primitives: Dual-Pivot Quick Sort

`Arrays.sort(int[])` (and the overloads for other primitive types) uses a **Dual-Pivot Quick Sort** algorithm introduced in Java 7 by Vladimir Yaroslavskiy. It selects two pivots and partitions the array into three segments:

```
[ < pivot1 | pivot1 <= x <= pivot2 | > pivot2 ]
```

This approach reduces the number of comparisons by roughly 20% compared to classic single-pivot Quick Sort. For small sub-arrays (below a threshold, typically 47 elements), it switches to **Insertion Sort**.

```java
int[] numbers = {38, 27, 43, 3, 9, 82, 10};
Arrays.sort(numbers);
// Result: [3, 9, 10, 27, 38, 43, 82]
```

### Arrays.sort and Collections.sort for Objects: TimSort

`Arrays.sort(Object[])` and `Collections.sort(List)` use **TimSort**, a hybrid algorithm combining Merge Sort and Insertion Sort, designed by Tim Peters for Python and adapted for Java.

TimSort works by:

1. Scanning the array for naturally occurring ascending or descending **runs** (pre-sorted subsequences).
2. Extending short runs to a minimum length using **Insertion Sort**.
3. Merging runs in a carefully balanced order that maintains stability and minimizes the number of merge operations.

```java
List<String> names = Arrays.asList("Charlie", "Alice", "Bob", "Alice");
Collections.sort(names);
// Result: [Alice, Alice, Bob, Charlie]
// The two "Alice" entries retain their original relative order (stable).
```

TimSort's key advantage is its ability to exploit existing order in the data. On already-sorted or nearly-sorted input, it runs in O(n). On random data, it matches Merge Sort's O(n log n). This makes it an excellent default for real-world data, which often contains some degree of pre-existing order.

### Sorting with Custom Comparators

Both `Arrays.sort` and `Collections.sort` accept a `Comparator` for custom ordering:

```java
String[] words = {"banana", "apple", "cherry", "date"};
Arrays.sort(words, Comparator.comparingInt(String::length));
// Result: [date, apple, banana, cherry]
```

For more complex sorting criteria, chain comparators:

```java
record Employee(String department, String name, int salary) {}

List<Employee> employees = List.of(
    new Employee("Engineering", "Alice", 95000),
    new Employee("Marketing", "Bob", 72000),
    new Employee("Engineering", "Charlie", 88000),
    new Employee("Marketing", "Diana", 72000)
);

List<Employee> sorted = employees.stream()
    .sorted(Comparator.comparing(Employee::department)
                       .thenComparing(Employee::name)
                       .thenComparingInt(Employee::salary))
    .toList();
```

Because TimSort is stable, sorting by department first and then by name within each department produces the expected result -- employees within the same department are ordered by name, and employees with the same department and name are ordered by salary.

### Parallel Sorting

For large arrays, `Arrays.parallelSort` splits the work across multiple threads using the Fork/Join framework:

```java
int[] large = new int[10_000_000];
ThreadLocalRandom.current().ints(large.length).forEach(i -> large[i] = i);
Arrays.parallelSort(large);
```

`parallelSort` uses the same underlying algorithms (Dual-Pivot Quick Sort for primitives, TimSort for objects) but divides the array into sub-arrays that are sorted in parallel and then merged. For arrays significantly larger than 8192 elements (the minimum granularity), it can be substantially faster on multi-core machines.

## Choosing the Right Algorithm

In practice, **use Java's built-in `Arrays.sort` or `Collections.sort`** unless you have a specific reason not to. They are battle-tested, highly optimized, and handle edge cases correctly.

When implementing your own sort -- for educational purposes, specialized hardware constraints, or domain-specific optimizations -- use this decision framework:

| Situation | Recommended Algorithm |
|-----------|----------------------|
| Small arrays (< 50 elements) | Insertion Sort |
| General purpose, in-place | Quick Sort (with median-of-three) |
| Guaranteed O(n log n), minimal memory | Heap Sort |
| Stability required | Merge Sort |
| Nearly sorted data | Insertion Sort or TimSort |
| Integers in a small range | Counting Sort |
| Large arrays, multi-core available | `Arrays.parallelSort` |

## Summary

Sorting algorithms represent a rich spectrum of trade-offs between time complexity, space usage, stability, and real-world performance:

- **Bubble, Selection, and Insertion Sort** are O(n²) algorithms useful for small inputs or as building blocks. Insertion Sort stands out for nearly sorted data.
- **Merge Sort** guarantees O(n log n) and stability at the cost of O(n) extra space.
- **Quick Sort** is the fastest general-purpose comparison sort in practice, with O(n log n) average time and O(1) extra space, but O(n²) worst case.
- **Heap Sort** provides O(n log n) guaranteed with O(1) space, but poor cache behavior.
- **Counting Sort** breaks the O(n log n) comparison-sort lower bound for restricted integer inputs.
- **TimSort** combines the best properties of Merge Sort and Insertion Sort, exploiting natural order in real-world data -- and it is what Java uses by default for objects.

Understanding these algorithms gives you the foundation to make informed decisions, even when the right answer is simply `Arrays.sort`.

## Sources

- [Arrays.sort -- Java SE 21 API Documentation](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Arrays.html#sort(int%5B%5D)) -- Oracle
- [Collections.sort -- Java SE 21 API Documentation](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Collections.html#sort(java.util.List)) -- Oracle
- [Dual-Pivot Quicksort -- Vladimir Yaroslavskiy](https://codeblab.com/wp-content/uploads/2009/09/DualPivotQuicksort.pdf)
- [TimSort -- Wikipedia](https://en.wikipedia.org/wiki/Timsort)
- [Introduction to Algorithms, 4th Edition](https://mitpress.mit.edu/9780262046305/) -- Cormen, Leiserson, Rivest, Stein (MIT Press)
