import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { JwtPayload } from '../jwt-payload.interface';

export const ConnectedUser = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): JwtPayload => {
    const type = ctx.getType();

    if (type === 'http') {
      const request = ctx.switchToHttp().getRequest();
      return request.user as JwtPayload;
    }

    if (type === 'ws') {
      const client = ctx.switchToWs().getClient();
      return client.data.user as JwtPayload;
    }

    return {} as JwtPayload;
  },
);
