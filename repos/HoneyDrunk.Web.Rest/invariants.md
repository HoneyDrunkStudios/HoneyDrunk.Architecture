# HoneyDrunk.Web.Rest — Invariants

1. **Every response uses `ApiResult<T>` or `ApiErrorResponse`.** No raw JSON objects.
2. **Correlation ID is always present in responses.** Set from `IOperationContext.CorrelationId`.
3. **Exceptions are never leaked to clients.** `ExceptionMappingMiddleware` converts all exceptions to structured error responses.
4. **JSON is always camelCase with enums as strings.**
