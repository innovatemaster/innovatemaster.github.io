---
layout: post
title: Architecture with Arc42
date: 2025-02-24 17:11 +0100
categories: [Architecture]
tags: [Arc42]
description: This post is about the architecture framework Arc42. It's a great way to document your architecture of your system.
---
# Architecture with Arc42
If you are working on a software project, you should document your architecture. One way to do this is with the arc42 template. It's a great way to document your architecture of your system.

## What is arc42?
Arc42 is a template for documenting software and system architectures. It's based on the ISO/IEC/IEEE 42010 standard, which is the international standard for architecture descriptions of systems and software. The arc42 template provides a structure for documenting the architecture of a system, including its stakeholders, requirements, constraints, and decisions.

## Why use arc42?
Standardization: Arc42 provides a standardized way to document software architectures, making it easier for stakeholders to understand and review the architecture of a system.

Completeness: The arc42 template covers all aspects of a software architecture, including stakeholders, requirements, constraints, and decisions, ensuring that all important aspects of the architecture are documented.

Consistency: By using the arc42 template, you can ensure that all software architectures in your organization are documented in a consistent way, making it easier to compare and review architectures.

## How to use arc42?
To use arc42,
you can download the template from the arc42 website and fill in the sections with information about your system.
The template includes sections for stakeholders, requirements, constraints, decisions, and views,
which you can use to document the architecture of your system.  
https://arc42.org/ or https://arc42.de/

# Structure of arc42
The arc42 template consists of 12 sections, which cover all aspects of a software architecture. The sections are:

## 1. Introduction and Goals
Fundamental requirements, esp. quality goals

Short description of the requirements, driving forces, extract (or abstract) of requirements. Top three (max five) quality goals for the architecture which have highest priority for the major stakeholders. A table of important stakeholders with their expectation regarding architecture.

## 2. Constraints
Regulations and external constraints

Anything that constrains teams in design and implementation decisions or decision about related processes. Can sometimes go beyond individual systems and are valid for whole organizations and companies.

## 3. Context & Scope
External systems & interfaces

Delimits your system from its (external) communication partners (neighboring systems and users). Specifies the external interfaces. Shown from a business/domain perspective (always) or a technical perspective (optional)

## 4. Solution Strategy
Core ideas and solution approaches

Summary of the fundamental decisions and solution strategies that shape the architecture. Can include technology, top-level decomposition, approaches to achieve top quality goals and relevant organizational decisions.

## 5. Building Block View
Structure of source code, modularization (hierarchical)

This section describes the building blocks of the system, including the components,
interfaces, and relationships between the building blocks. 

## 6. Runtime View
Important runtime scenarios

Behavior of building blocks as scenarios, covering important use cases or features, interactions at critical external interfaces, operation and administration plus error and exception behavior.

## 7. Deployment View
Hardware, infrastructure & deployment

Technical infrastructure with environments, computers, processors, topologies. Mapping of (software) building blocks to infrastructure elements.

## 8. Crosscutting Concepts
Cross-cutting topics, often very technical and detailed

Overall, principal regulations and solution approaches relevant in multiple parts (→ cross-cutting) of the system. Concepts are often related to multiple building blocks. Include different topics like domain models, architecture patterns and -styles, rules for using specific technology and implementation rules.

## 9. Architectural Decisions
Important decisions (not described elsewhere)

Important, expensive, critical, large scale or risky architecture decisions including rationales.

## 10. Quality Requirements
Quality tree, quality scenarios

Quality requirements as scenarios, with quality tree to provide high-level overview. The most important quality goals should have been described in section 1.2. (quality goals).

## 11. Risks and Technical Debt
Known problems and risks

Known technical risks or technical debt. What potential problems exist within or around the system? What does the development team feel miserable about?

## 12. Glossary
Important specific terms ("ubiquitous language")

Important domain and technical terms that stakeholders use when discussing the system. Also: translation reference if you work in a multi-language environment.

# Conclusion
Arc42 is a great way to document your architecture of your system. It provides a standardized way to document software architectures, making it easier for stakeholders to understand and review the architecture of a system. By using the arc42 template, you can ensure that all software architectures in your organization are documented in a consistent way, making it easier to compare and review architectures.
