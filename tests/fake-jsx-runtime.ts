import { createComponent } from "solid-js"

// A renderer-free JSX runtime for tests. Function components (Show) go through
// Solid's createComponent; intrinsic elements (box, text) stay as plain data.
export function jsx(type: string | ((props: any) => any), props: any = {}) {
  if (typeof type === "function") {
    return createComponent(type, props)
  }
  return { type, props: props ?? {} }
}

export const jsxs = jsx
export const jsxDEV = jsx

export function Fragment(props: any) {
  return props?.children ?? null
}
