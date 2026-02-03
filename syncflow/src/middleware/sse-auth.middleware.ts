import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class SseAuthMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const token = req.query.authorization;

    if (token && typeof token === 'string') {
      req.headers['authorization'] = `Bearer ${token}`;
    }

    next(); // Call next() to pass control to the next middleware/controller
  }
}
