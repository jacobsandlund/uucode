fn maybePackedInit(
    comptime field: []const u8,
    data: anytype,
    tracking: anytype,
    d: anytype,
) void {
    const Field = @FieldType(@typeInfo(@TypeOf(data)).pointer.child, field);
    if (@typeInfo(Field) == .@"struct" and @hasDecl(Field, "init")) {
        @field(data, field) = .init(d);
    } else {
        @field(data, field) = d;
    }
    const Tracking = @typeInfo(@TypeOf(tracking)).pointer.child;
    if (@hasField(Tracking, field)) {
        @field(tracking, field).track(d);
    }
}

        const get_data_end = try std.time.Instant.now();
        get_data_time += get_data_end.since(get_data_start);

        var a: AllData = undefined;

        if (comptime Ucd.needsSection(table_config, .unicode_data)) {
            const unicode_data = &ucd.unicode_data[cp];

            if (@hasField(AllData, "name")) {
                a.name = try .init(
                    allocator,
                    backing.name,
                    &tracking.name,
                    unicode_data.name,
                );
            }
            if (@hasField(AllData, "general_category")) {
                a.general_category = unicode_data.general_category;
            }
            if (@hasField(AllData, "canonical_combining_class")) {
                a.canonical_combining_class = unicode_data.canonical_combining_class;
            }
            if (@hasField(AllData, "decomposition_type")) {
                a.decomposition_type = unicode_data.decomposition_type;
            }
            if (@hasField(AllData, "decomposition_mapping")) {
                a.decomposition_mapping = try .initFor(
                    allocator,
                    backing.decomposition_mapping,
                    &tracking.decomposition_mapping,
                    unicode_data.decomposition_mapping,
                    cp,
                );
            }
            if (@hasField(AllData, "numeric_type")) {
                a.numeric_type = unicode_data.numeric_type;
            }
            if (@hasField(AllData, "numeric_value_decimal")) {
                maybePackedInit(
                    "numeric_value_decimal",
                    &a,
                    &tracking,
                    unicode_data.numeric_value_decimal,
                );
            }
            if (@hasField(AllData, "numeric_value_digit")) {
                maybePackedInit(
                    "numeric_value_digit",
                    &a,
                    &tracking,
                    unicode_data.numeric_value_digit,
                );
            }
            if (@hasField(AllData, "numeric_value_numeric")) {
                a.numeric_value_numeric = try .init(
                    allocator,
                    backing.numeric_value_numeric,
                    &tracking.numeric_value_numeric,
                    unicode_data.numeric_value_numeric,
                );
            }
            if (@hasField(AllData, "is_bidi_mirrored")) {
                a.is_bidi_mirrored = unicode_data.is_bidi_mirrored;
            }
            if (@hasField(AllData, "unicode_1_name")) {
                a.unicode_1_name = try .init(
                    allocator,
                    backing.unicode_1_name,
                    &tracking.unicode_1_name,
                    unicode_data.unicode_1_name,
                );
            }
            if (@hasField(AllData, "simple_uppercase_mapping")) {
                types.fieldInit(
                    "simple_uppercase_mapping",
                    cp,
                    &a,
                    &tracking,
                    unicode_data.simple_uppercase_mapping,
                );
            }
            if (@hasField(AllData, "simple_lowercase_mapping")) {
                types.fieldInit(
                    "simple_lowercase_mapping",
                    cp,
                    &a,
                    &tracking,
                    unicode_data.simple_lowercase_mapping,
                );
            }
            if (@hasField(AllData, "simple_titlecase_mapping")) {
                types.fieldInit(
                    "simple_titlecase_mapping",
                    cp,
                    &a,
                    &tracking,
                    unicode_data.simple_titlecase_mapping,
                );
            }
        }

        // BidiClass
        if (@hasField(AllData, "bidi_class")) {
            comptime inlineAssert(Ucd.needsSection(table_config, .derived_bidi_class));
            const derived_bidi_class = ucd.derived_bidi_class[cp];
            inlineAssert((comptime !Ucd.needsSection(table_config, .unicode_data)) or
                (ucd.unicode_data[cp].bidi_class == null or ucd.unicode_data[cp].bidi_class.? == derived_bidi_class));
            a.bidi_class = derived_bidi_class;
        }

        if (comptime Ucd.needsSection(table_config, .case_folding)) {
            const case_folding = &ucd.case_folding[cp];

            if (@hasField(AllData, "case_folding_simple")) {
                const d =
                    case_folding.case_folding_simple_only orelse
                    case_folding.case_folding_common_only orelse

                    // This would seem not to be necessary based on the heading
                    // of CaseFolding.txt, but U+0130 has only an F and T
                    // mapping and no S. The T mapping is the same as the
                    // simple_lowercase_mapping so we use that here.
                    case_folding.case_folding_turkish_only orelse
                    cp;
                types.fieldInit("case_folding_simple", cp, &a, &tracking, d);
            }
            if (@hasField(AllData, "case_folding_full")) {
                if (case_folding.case_folding_full_only.len > 0) {
                    a.case_folding_full = try .initFor(
                        allocator,
                        backing.case_folding_full,
                        &tracking.case_folding_full,
                        case_folding.case_folding_full_only,
                        cp,
                    );
                } else {
                    a.case_folding_full = try .initFor(
                        allocator,
                        backing.case_folding_full,
                        &tracking.case_folding_full,
                        &.{case_folding.case_folding_common_only orelse cp},
                        cp,
                    );
                }
            }
            if (@hasField(AllData, "case_folding_turkish_only")) {
                if (case_folding.case_folding_turkish_only) |t| {
                    a.case_folding_turkish_only = try .initFor(
                        allocator,
                        backing.case_folding_turkish_only,
                        &tracking.case_folding_turkish_only,
                        &.{t},
                        cp,
                    );
                } else {
                    a.case_folding_turkish_only = .empty;
                }
            }
            if (@hasField(AllData, "case_folding_common_only")) {
                if (case_folding.case_folding_common_only) |c| {
                    a.case_folding_common_only = try .initFor(
                        allocator,
                        backing.case_folding_common_only,
                        &tracking.case_folding_common_only,
                        &.{c},
                        cp,
                    );
                } else {
                    a.case_folding_common_only = .empty;
                }
            }
            if (@hasField(AllData, "case_folding_simple_only")) {
                if (case_folding.case_folding_simple_only) |s| {
                    a.case_folding_simple_only = try .initFor(
                        allocator,
                        backing.case_folding_simple_only,
                        &tracking.case_folding_simple_only,
                        &.{s},
                        cp,
                    );
                } else {
                    a.case_folding_simple_only = .empty;
                }
            }
            if (@hasField(AllData, "case_folding_full_only")) {
                a.case_folding_full_only = try .initFor(
                    allocator,
                    backing.case_folding_full_only,
                    &tracking.case_folding_full_only,
                    case_folding.case_folding_full_only,
                    cp,
                );
            }
        }

        if (comptime Ucd.needsSection(table_config, .special_casing)) {
            const special_casing = &ucd.special_casing[cp];

            if (@hasField(AllData, "has_special_casing")) {
                a.has_special_casing = special_casing.has_special_casing;
            }
            if (@hasField(AllData, "special_lowercase_mapping")) {
                a.special_lowercase_mapping = try .initFor(
                    allocator,
                    backing.special_lowercase_mapping,
                    &tracking.special_lowercase_mapping,
                    special_casing.special_lowercase_mapping,
                    cp,
                );
            }
            if (@hasField(AllData, "special_titlecase_mapping")) {
                a.special_titlecase_mapping = try .initFor(
                    allocator,
                    backing.special_titlecase_mapping,
                    &tracking.special_titlecase_mapping,
                    special_casing.special_titlecase_mapping,
                    cp,
                );
            }
            if (@hasField(AllData, "special_uppercase_mapping")) {
                a.special_uppercase_mapping = try .initFor(
                    allocator,
                    backing.special_uppercase_mapping,
                    &tracking.special_uppercase_mapping,
                    special_casing.special_uppercase_mapping,
                    cp,
                );
            }
            if (@hasField(AllData, "special_casing_condition")) {
                a.special_casing_condition = try .init(
                    allocator,
                    backing.special_casing_condition,
                    &tracking.special_casing_condition,
                    special_casing.special_casing_condition,
                );
            }
        }

        // Case mappings
        if (@hasField(AllData, "lowercase_mapping") or
            @hasField(AllData, "titlecase_mapping") or
            @hasField(AllData, "uppercase_mapping"))
        {
            const unicode_data = &ucd.unicode_data[cp];
            const special_casing = &ucd.special_casing[cp];

            if (@hasField(AllData, "lowercase_mapping")) {
                const use_special = special_casing.has_special_casing and
                    special_casing.special_casing_condition.len == 0;

                if (use_special) {
                    a.lowercase_mapping = try .initFor(
                        allocator,
                        backing.lowercase_mapping,
                        &tracking.lowercase_mapping,
                        special_casing.special_lowercase_mapping,
                        cp,
                    );
                } else {
                    a.lowercase_mapping = try .initFor(
                        allocator,
                        backing.lowercase_mapping,
                        &tracking.lowercase_mapping,
                        &.{unicode_data.simple_lowercase_mapping},
                        cp,
                    );
                }
            }

            if (@hasField(AllData, "titlecase_mapping")) {
                const use_special = special_casing.has_special_casing and
                    special_casing.special_casing_condition.len == 0;

                if (use_special) {
                    a.titlecase_mapping = try .initFor(
                        allocator,
                        backing.titlecase_mapping,
                        &tracking.titlecase_mapping,
                        special_casing.special_titlecase_mapping,
                        cp,
                    );
                } else {
                    a.titlecase_mapping = try .initFor(
                        allocator,
                        backing.titlecase_mapping,
                        &tracking.titlecase_mapping,
                        &.{unicode_data.simple_titlecase_mapping},
                        cp,
                    );
                }
            }

            if (@hasField(AllData, "uppercase_mapping")) {
                const use_special = special_casing.has_special_casing and
                    special_casing.special_casing_condition.len == 0;

                if (use_special) {
                    a.uppercase_mapping = try .initFor(
                        allocator,
                        backing.uppercase_mapping,
                        &tracking.uppercase_mapping,
                        special_casing.special_uppercase_mapping,
                        cp,
                    );
                } else {
                    a.uppercase_mapping = try .initFor(
                        allocator,
                        backing.uppercase_mapping,
                        &tracking.uppercase_mapping,
                        &.{unicode_data.simple_uppercase_mapping},
                        cp,
                    );
                }
            }
        }

        if (comptime Ucd.needsSection(table_config, .derived_core_properties)) {
            const derived_core_properties = &ucd.derived_core_properties[cp];

            if (@hasField(AllData, "is_math")) {
                a.is_math = derived_core_properties.is_math;
            }
            if (@hasField(AllData, "is_alphabetic")) {
                a.is_alphabetic = derived_core_properties.is_alphabetic;
            }
            if (@hasField(AllData, "is_lowercase")) {
                a.is_lowercase = derived_core_properties.is_lowercase;
            }
            if (@hasField(AllData, "is_uppercase")) {
                a.is_uppercase = derived_core_properties.is_uppercase;
            }
            if (@hasField(AllData, "is_cased")) {
                a.is_cased = derived_core_properties.is_cased;
            }
            if (@hasField(AllData, "is_case_ignorable")) {
                a.is_case_ignorable = derived_core_properties.is_case_ignorable;
            }
            if (@hasField(AllData, "changes_when_lowercased")) {
                a.changes_when_lowercased = derived_core_properties.changes_when_lowercased;
            }
            if (@hasField(AllData, "changes_when_uppercased")) {
                a.changes_when_uppercased = derived_core_properties.changes_when_uppercased;
            }
            if (@hasField(AllData, "changes_when_titlecased")) {
                a.changes_when_titlecased = derived_core_properties.changes_when_titlecased;
            }
            if (@hasField(AllData, "changes_when_casefolded")) {
                a.changes_when_casefolded = derived_core_properties.changes_when_casefolded;
            }
            if (@hasField(AllData, "changes_when_casemapped")) {
                a.changes_when_casemapped = derived_core_properties.changes_when_casemapped;
            }
            if (@hasField(AllData, "is_id_start")) {
                a.is_id_start = derived_core_properties.is_id_start;
            }
            if (@hasField(AllData, "is_id_continue")) {
                a.is_id_continue = derived_core_properties.is_id_continue;
            }
            if (@hasField(AllData, "is_xid_start")) {
                a.is_xid_start = derived_core_properties.is_xid_start;
            }
            if (@hasField(AllData, "is_xid_continue")) {
                a.is_xid_continue = derived_core_properties.is_xid_continue;
            }
            if (@hasField(AllData, "is_default_ignorable")) {
                a.is_default_ignorable = derived_core_properties.is_default_ignorable;
            }
            if (@hasField(AllData, "is_grapheme_extend")) {
                a.is_grapheme_extend = derived_core_properties.is_grapheme_extend;
            }
            if (@hasField(AllData, "is_grapheme_base")) {
                a.is_grapheme_base = derived_core_properties.is_grapheme_base;
            }
            if (@hasField(AllData, "is_grapheme_link")) {
                a.is_grapheme_link = derived_core_properties.is_grapheme_link;
            }
            if (@hasField(AllData, "indic_conjunct_break")) {
                a.indic_conjunct_break = derived_core_properties.indic_conjunct_break;
            }
        }

        // EastAsianWidth
        if (@hasField(AllData, "east_asian_width")) {
            const east_asian_width = ucd.east_asian_width[cp];
            a.east_asian_width = east_asian_width;
        }

        // Block
        if (@hasField(AllData, "block")) {
            const block_value = ucd.blocks[cp];
            a.block = block_value;
        }

        // Script
        if (@hasField(AllData, "script")) {
            const script_value = ucd.scripts[cp];
            a.script = script_value;
        }

        // Joining Type
        if (@hasField(AllData, "joining_type")) {
            const jt_value = ucd.joining_types[cp];
            a.joining_type = jt_value;
        }

        // Joining Group
        if (@hasField(AllData, "joining_group")) {
            const jg_value = ucd.joining_groups[cp];
            a.joining_group = jg_value;
        }

        // Composition Exclusions
        if (@hasField(AllData, "is_composition_exclusion")) {
            const exclusion = ucd.is_composition_exclusions[cp];
            a.is_composition_exclusion = exclusion;
        }

        // Indic Positional Category
        if (@hasField(AllData, "indic_positional_category")) {
            const ipc = ucd.indic_positional_category[cp];
            a.indic_positional_category = ipc;
        }

        // Indic Syllabic Category
        if (@hasField(AllData, "indic_syllabic_category")) {
            const ipc = ucd.indic_syllabic_category[cp];
            a.indic_syllabic_category = ipc;
        }

        // OriginalGraphemeBreak
        if (@hasField(AllData, "original_grapheme_break")) {
            const original_grapheme_break = ucd.original_grapheme_break[cp];
            a.original_grapheme_break = original_grapheme_break;
        }

        // EmojiData
        if (comptime Ucd.needsSection(table_config, .emoji_data)) {
            const emoji_data = &ucd.emoji_data[cp];

            if (@hasField(AllData, "is_emoji")) {
                a.is_emoji = emoji_data.is_emoji;
            }
            if (@hasField(AllData, "is_emoji_presentation")) {
                a.is_emoji_presentation = emoji_data.is_emoji_presentation;
            }
            if (@hasField(AllData, "is_emoji_modifier")) {
                a.is_emoji_modifier = emoji_data.is_emoji_modifier;
            }
            if (@hasField(AllData, "is_emoji_modifier_base")) {
                a.is_emoji_modifier_base = emoji_data.is_emoji_modifier_base;
            }
            if (@hasField(AllData, "is_emoji_component")) {
                a.is_emoji_component = emoji_data.is_emoji_component;
            }
            if (@hasField(AllData, "is_extended_pictographic")) {
                a.is_extended_pictographic = emoji_data.is_extended_pictographic;
            }
        }

        if (comptime Ucd.needsSection(table_config, .emoji_vs)) {
            const emoji_vs = &ucd.emoji_vs[cp];

            if (@hasField(AllData, "is_emoji_vs_base")) {
                inlineAssert(emoji_vs.is_text == emoji_vs.is_emoji);
                a.is_emoji_vs_base = emoji_vs.is_text;
            }
            if (@hasField(AllData, "is_emoji_vs_text")) {
                a.is_emoji_vs_text = emoji_vs.is_text;
            }
            if (@hasField(AllData, "is_emoji_vs_emoji")) {
                a.is_emoji_vs_emoji = emoji_vs.is_emoji;
            }
        }

        if (@hasField(AllData, "bidi_paired_bracket")) {
            const bidi_paired_bracket = ucd.bidi_paired_bracket[cp];
            types.fieldInit(
                "bidi_paired_bracket",
                cp,
                &a,
                &tracking,
                bidi_paired_bracket,
            );
        }

        if (@hasField(AllData, "bidi_mirroring")) {
            const bidi_mirroring = ucd.bidi_mirroring[cp];
            types.fieldInit(
                "bidi_mirroring",
                cp,
                &a,
                &tracking,
                bidi_mirroring,
            );
        }

        // GraphemeBreak
        if (@hasField(AllData, "grapheme_break")) {
            const emoji_data = &ucd.emoji_data[cp];
            const original_grapheme_break = ucd.original_grapheme_break[cp];
            const derived_core_properties = &ucd.derived_core_properties[cp];

            if (emoji_data.is_emoji_modifier) {
                inlineAssert(original_grapheme_break == .extend);
                inlineAssert(!emoji_data.is_extended_pictographic and
                    emoji_data.is_emoji_component);
                a.grapheme_break = .emoji_modifier;
            } else if (emoji_data.is_emoji_modifier_base) {
                inlineAssert(original_grapheme_break == .other);
                inlineAssert(emoji_data.is_extended_pictographic);
                a.grapheme_break = .emoji_modifier_base;
            } else if (emoji_data.is_extended_pictographic) {
                inlineAssert(original_grapheme_break == .other);
                a.grapheme_break = .extended_pictographic;
            } else {
                switch (derived_core_properties.indic_conjunct_break) {
                    .none => {
                        @setEvalBranchQuota(50_000);
                        a.grapheme_break = switch (original_grapheme_break) {
                            .extend => blk: {
                                if (cp == config.zero_width_non_joiner) {
                                    // `zwnj` is the only grapheme break
                                    // `extend` that is `none` for Indic
                                    // conjunct break as opposed to ICB
                                    // `extend` or `linker`.
                                    break :blk .zwnj;
                                } else {
                                    std.log.err(
                                        "Found an `extend` grapheme break that is Indic conjunct break `none` (and not zwnj): {x}",
                                        .{cp},
                                    );
                                    unreachable;
                                }
                            },
                            inline else => |o| comptime std.meta.stringToEnum(
                                types.GraphemeBreak,
                                @tagName(o),
                            ) orelse unreachable,
                        };
                    },
                    .extend => {
                        if (cp == config.zero_width_joiner) {
                            inlineAssert(original_grapheme_break == .zwj);
                            a.grapheme_break = .zwj;
                        } else {
                            inlineAssert(original_grapheme_break == .extend);
                            a.grapheme_break = .indic_conjunct_break_extend;
                        }
                    },
                    .linker => {
                        inlineAssert(original_grapheme_break == .extend);
                        a.grapheme_break = .indic_conjunct_break_linker;
                    },
                    .consonant => {
                        inlineAssert(original_grapheme_break == .other);
                        a.grapheme_break = .indic_conjunct_break_consonant;
                    },
                }
            }
        }

        inline for (table_config.extensions) |extension| {
            try extension.compute(allocator, cp, &a, &backing, &tracking);
        }
