module AlgoliaWriter

import Base.Markdown: isordered

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities,
    Writers,
    Writers.HTMLWriter

using ...Utilities.MDFlatten

import Base.show

mutable struct AlgoliaItem
    doc::Documents.Document
    items::Vector{Any}
    level::Int
    menu::Vector{String}
    sections::Vector{String}
    insignificance::Int
    url::String
    anchor::String
end

struct TextItem
    url::String
    heading::Union{Int,Void}
    content::String
    insignificance::Int
    lvl1::String
    lvl2::String
    lvl3::String
    lvl4::String
    lvl5::String
    lvl6::String
    lvl7::String
end

struct CodeExample
    url::String
    content::String
    insignificance::Int
    lvl1::String
    lvl2::String
    lvl3::String
    lvl4::String
    lvl5::String
    lvl6::String
    lvl7::String
end

struct DefinitionItem
    url::String
    full::String
    short::String
    content::String
    category::String
    insignificance::Int
    lvl1::String
    lvl2::String
    lvl3::String
    lvl4::String
    lvl5::String
    lvl6::String
    lvl7::String
end

AlgoliaItem(doc) = AlgoliaItem(doc, [], 0, Vector{String}(), Vector{String}(7), 0, "", "")

function render(doc::Documents.Document)
    ctx = AlgoliaItem(doc)
    recurse_pages(ctx, doc.internal.navtree, 0)

    io = IOBuffer()

    println(io, "[")
    for (i, item) in enumerate(ctx.items)
        render(io, item)
        if i < length(ctx.items)
            print(io, ",")
        end
    end
    println(io, "]")

    open(joinpath(doc.user.build, "index.json"), "w+") do write_io
        write(write_io, String(take!(io)))
    end
end

function recurse_pages(ctx, navnodes, depth)
    for node in navnodes
        if node.title_override !== nothing
            push!(ctx.menu, node.title_override)
        end

        if node.page !== nothing
            ctx.url = HTMLWriter.get_url(ctx, node)
            render_page(ctx, node.page)
        end

        if !isempty(node.children)
            recurse_pages(ctx, node.children, depth + 1)
        end

        if node.title_override !== nothing
            pop!(ctx.menu)
        end

    end
end

function render_page(ctx, path)
    page = ctx.doc.internal.pages[path]

    for el in page.elements
        related = page.mapping[el]
        handle_header!(ctx, el, related)
        index_section!(ctx, related)
    end
end

handle_header!(_...) = nothing

function handle_header!(ctx::AlgoliaItem, el::Base.Markdown.Header{N}, anchor) where {N}
    ctx.anchor = "$(anchor.id)-$(anchor.nth)"
    ctx.level = N
    ctx.sections[N] = MDFlatten.mdflatten(el.text)
    ctx.insignificance += 1

    push!(ctx.items, TextItem(
        ctx.url * "#" * ctx.anchor, 
        N,
        strip(MDFlatten.mdflatten(el)),
        ctx.insignificance,
        get_titles(ctx)...
    ))
end

const PlainText = Union{Base.Markdown.Paragraph,Base.Markdown.List}

index_section!(_...) = false

function index_section!(ctx::AlgoliaItem, el::PlainText)
    ctx.insignificance += 1

    push!(ctx.items, TextItem(
        ctx.url * "#" * ctx.anchor,
        nothing,
        strip(MDFlatten.mdflatten(el)),
        ctx.insignificance,
        get_titles(ctx)...
    ))
end

function index_section!(ctx::AlgoliaItem, el::Base.Markdown.Code)
    ctx.insignificance += 1
    
    push!(ctx.items, CodeExample(
        ctx.url * "#" * ctx.anchor,
        strip(MDFlatten.mdflatten(el)),
        ctx.insignificance,
        get_titles(ctx)...
    ))
end

function index_section!(ctx::AlgoliaItem, el::Documents.DocsNodes)
    for node in el.nodes
        ctx.insignificance += 1

        push!(ctx.items, DefinitionItem(
            ctx.url * "#" * string(node.anchor.id),
            string(node.object.binding),
            string(node.object.binding.var),
            strip(MDFlatten.mdflatten(node.docstr)),
            string(Symbol(Utilities.doccat(node.object))),
            ctx.insignificance,
            get_titles(ctx)...
        ))
    end
end

function get_titles(ctx)
    titles = fill("", 7)
    i = 1
    for title in ctx.menu
        titles[i] = title
        i += 1
    end

    for j = 1 : ctx.level
        titles[i] = ctx.sections[j]
        i += 1
    end
    titles
end

function render(io, item::TextItem)
    println(io,"""
{
    "type": "Documentation",
    "url": "$(HTMLWriter.jsonescape(item.url))",
    "content": "$(HTMLWriter.jsonescape(item.content))",
    "insignificance": $(item.insignificance),
    "lvl1": "$(HTMLWriter.jsonescape(item.lvl1))",
    "lvl2": "$(HTMLWriter.jsonescape(item.lvl2))",
    "lvl3": "$(HTMLWriter.jsonescape(item.lvl3))",
    "lvl4": "$(HTMLWriter.jsonescape(item.lvl4))",
    "lvl5": "$(HTMLWriter.jsonescape(item.lvl5))",
    "lvl6": "$(HTMLWriter.jsonescape(item.lvl6))",
    "lvl7": "$(HTMLWriter.jsonescape(item.lvl7))"
""")
    if isa(item.heading, Int)
        println(io, ""","header$(item.heading)": "$(HTMLWriter.jsonescape(item.content))" """)
    end
    println(io, "}")
end

function render(io, item::CodeExample)
    println(io,"""
{
    "type": "Code",
    "url": "$(HTMLWriter.jsonescape(item.url))",
    "content": "$(HTMLWriter.jsonescape(item.content))",
    "insignificance": 100000,
    "lvl1": "$(HTMLWriter.jsonescape(item.lvl1))",
    "lvl2": "$(HTMLWriter.jsonescape(item.lvl2))",
    "lvl3": "$(HTMLWriter.jsonescape(item.lvl3))",
    "lvl4": "$(HTMLWriter.jsonescape(item.lvl4))",
    "lvl5": "$(HTMLWriter.jsonescape(item.lvl5))",
    "lvl6": "$(HTMLWriter.jsonescape(item.lvl6))",
    "lvl7": "$(HTMLWriter.jsonescape(item.lvl7))"
}
""")
end

function render(io, item::DefinitionItem)
    println(io,"""
{
    "type": "Definition",
    "url": "$(HTMLWriter.jsonescape(item.url))",
    "full": "$(HTMLWriter.jsonescape(item.full))",
    "short": "$(HTMLWriter.jsonescape(item.short))",
    "content": "$(HTMLWriter.jsonescape(item.content))",
    "category": "$(HTMLWriter.jsonescape(item.category))",
    "insignificance": $(item.insignificance),
    "lvl1": "$(HTMLWriter.jsonescape(item.lvl1))",
    "lvl2": "$(HTMLWriter.jsonescape(item.lvl2))",
    "lvl3": "$(HTMLWriter.jsonescape(item.lvl3))",
    "lvl4": "$(HTMLWriter.jsonescape(item.lvl4))",
    "lvl5": "$(HTMLWriter.jsonescape(item.lvl5))",
    "lvl6": "$(HTMLWriter.jsonescape(item.lvl6))",
    "lvl7": "$(HTMLWriter.jsonescape(item.lvl7))"
}""")
end
end
