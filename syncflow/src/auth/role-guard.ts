import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from './decorator/roles.decorator';
import { Role } from 'src/enum/role.enum';
import { JwtPayload } from './jwt-payload.interface';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user as JwtPayload;

    if (!user || !user.role || !user.companyCode) {
      throw new ForbiddenException('Access denied: no valid user or company context.');
    }

    if (!requiredRoles.includes(user.role)) {
      throw new ForbiddenException(`Access denied: role ${user.role} is not permitted.`);
    }
  
    return true;
  }
}
