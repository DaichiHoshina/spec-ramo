# Code Quality and Design Philosophy

> **Purpose**: Quality criteria for consistency, readability, and testability. `/specramo:implement` applies them while writing code, `/specramo:phase-design` applies the naming part when it picks method names, and `/specramo:review` uses them as a review lens.

## Quick Reference

### Quality Standards

| Item | Rule |
|------|------|
| Consistency | Follow existing code style and design patterns |
| Readability | No self-indulgent coding |
| Magic numbers | Always extract as named constants |
| Naming | Apply the 3 naming criteria below to every function and variable name |

### Naming Criteria

Apply in this order. When two criteria conflict, the earlier one wins.

| # | Criterion | How to check |
|---|-----------|--------------|
| 1 | Use the words the repo already uses | Before naming, grep the same layer for names with the same role and count each candidate (`Find` vs `Get`, `order` vs `purchase`). Take the majority. For domain words, reuse the English the repo already maps to the PRD / Design Doc term |
| 2 | Use plain, common English | Pick words a non-native reader knows (`get` / `list` / `check` / `count`). Avoid rare words (`ascertain`, `procure`, `reconcile`) and made-up abbreviations. A rare word the repo already uses is fine under #1 |
| 3 | Keep it as short as it stays clear | Drop words the context already gives: the package / receiver / type name, the type in the name (`userList` → `users`), and filler (`Data`, `Info`, `Process`, `Handle`). Stop cutting when the name alone no longer tells two similar things apart |

Example: in `order` package, `GetOrderDataByOrderID` → `GetByID` (drop the filler `Data` and the repeated `Order`; keep the verb, since `Get` and `Find` can mean different things).

### Naming Shape

After the 3 criteria pick the words, shape the name with these rules. Repo conventions still win (#1).

| Rule | Avoid | Use |
|------|-------|-----|
| Variables are nouns for what the value is; functions are verbs for what they do | `data`, `result`, `handle()` | `selectedSize`, `calculateShippingFee()` |
| Booleans read as a yes/no question: `is` (state) / `has` (owns, exists) / `can` (allowed) / `should` (ought to) / `needs` (required) | `active`, `flag`, `check` | `isActive`, `hasSelectedSize`, `canCancel` |
| Plural for collections, singular for one item | `order []Order`, `productID []ProductID` | `orders`, `productIDs` |
| Name a state change by the business action, not by CRUD | `order.UpdateStatus(Canceled)`, `UpdateData()` | `order.Cancel()`, `ConfirmPayment()` |
| When a name gets long, first ask whether the type or package should carry the context. Cut words only after that | `getActiveOrderDeliveryOptionByShippingRequestID()` | `deliveryOption.FindActiveByShippingRequestID(id)` |
| Maps and records carry their key in the name | `userMap`, `orderArray` | `usersById`, `orders` |
| Filler words only when they add meaning: `data` / `info` / `item` / `value` / `result` / `obj` / `tmp` / `process` / `execute` / `handle` / `manager` / `util` / `helper` | `processData()`, `OrderData` | `calculateShippingFee()`, `Order` |

`handle` is fine for a React event handler (`handleSubmit`), because there it has one clear meaning.

**Verb meanings** (use when the repo has no convention; the repo's own usage wins under #1):

| Verb | Meaning | Example |
|------|---------|---------|
| `get` | Read a value that must exist | `getOrder(id)` |
| `find` | Search; the result may be missing | `findUserByEmail(email)` |
| `list` / `search` | Many items / many items by conditions | `listOrders()`, `searchProducts(query)` |
| `fetch` | Read over the network (HTTP / API) | `fetchOrders()` |
| `load` | Read and put into app or UI state | `loadUserPage(id)` |
| `new` / `create` / `build` | Make in memory / make and save / assemble from parts | `NewOrder()`, `createOrder(input)`, `buildShippingRequest(order)` |
| `parse` / `format` | Text to structured data / data to display text | `parseDate(text)`, `formatPrice(12800)` |
| `serialize` / `to` | Object to a storage or transfer form / A to B in general | `serializeForm(form)`, `toOrderDto(order)` |

Avoid `convert` / `process` when one of the verbs above fits.

**Same word across the stack**: the backend and the frontend use the same English word for one business concept. Do not name one thing `ShippingRequest` in Go and `DeliveryRequest` in TypeScript.

Check: translate the name into the language of the PRD. It should be a word the PRD, Design Doc, or issue already uses.

### Implementation Shape

Pick how code is wired (passing a transaction, constructor vs. plain function, field types of an existing type, error style) the same way as names: by the majority in the repo.

| Step | How |
|------|-----|
| 1. List the candidate shapes | e.g. a constructor that takes the transaction / a function that takes the transaction as an argument / changing a field of an existing type to hold the transaction |
| 2. Count each shape in the same layer | `git grep` on the default branch. Exclude the feature's own branch chain and the feature's own domain, so one earlier PR of the same feature does not count as "existing" |
| 3. Take the majority | One precedent is not enough when another shape has more. Record the counts and the chosen precedent as `file:line` on the default branch |
| 4. Prefer the shape that leaves existing code unchanged | A shape that needs changing an existing type's fields or signatures loses to one that only adds code, unless the majority says otherwise |

Example: to call a write inside another write's transaction, 22 existing functions take the transaction as an argument and keep the existing type unchanged, while a constructor that stores the transaction has 1 use. Take the function that receives the transaction.

### Comment Principles

- Default is no comment. Names and structure carry the "what"
- Leave a comment only for "why not": a constraint, a rejected alternative, or a reason the obvious approach fails here
- Do not leave comments that restate the code or narrate the change history (the commit message carries the "why")

### Design Philosophy

| Principle | Description |
|-----------|-------------|
| Layered architecture | Flexible design prioritizing ease of change |
| Readable code | Split hard-to-read code; avoid long functions |
| Dependencies | Keep loosely coupled; do not use components from other pages |
| API responses are raw data | Return raw data without UI-specific aggregations; enables reuse across multiple UIs and reduces server-side spec changes |
| Single point of change | Design so spec changes require changes in only one place; extract and consolidate any duplication |

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| `const name = "Taro"; // set the name` | `const name = "Taro";` | Obvious comment unnecessary |
| `const MAX = 100;` | `const MAX_RETRY_COUNT = 100;` | Name expresses intent |
| 200-line function | Split into 10-50-line functions | Improves readability and testability |
| Importing components from other pages | Commonalize or copy | Maintains loose coupling |
