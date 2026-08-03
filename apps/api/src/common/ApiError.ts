/**
 * Typed application error. Throw these from routes/services; the global
 * error middleware will translate them into JSON HTTP responses.
 */
export class ApiError extends Error {
  public readonly status: number;
  public readonly code: string;
  public readonly details?: unknown;

  constructor(status: number, code: string, message: string, details?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static badRequest(message = 'Bad request', details?: unknown): ApiError {
    return new ApiError(400, 'BAD_REQUEST', message, details);
  }
  static unauthorized(message = 'Unauthorized'): ApiError {
    return new ApiError(401, 'UNAUTHORIZED', message);
  }
  static forbidden(message = 'Forbidden'): ApiError {
    return new ApiError(403, 'FORBIDDEN', message);
  }
  static notFound(message = 'Not found'): ApiError {
    return new ApiError(404, 'NOT_FOUND', message);
  }
  static internal(message = 'Internal server error'): ApiError {
    return new ApiError(500, 'INTERNAL', message);
  }
}