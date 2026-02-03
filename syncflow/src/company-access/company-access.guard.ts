// src/company-access/company-access.guard.ts
import { Injectable, CanActivate, ExecutionContext, ForbiddenException, Type, mixin } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { JwtPayload } from '../auth/jwt-payload.interface';

export const CompanyAccessGuard = (entityClass: Type): Type<CanActivate> => {
  @Injectable()
  class CompanyAccessGuardMixin implements CanActivate {
    constructor(
      private readonly dataSource: DataSource,
    ) {}

    async canActivate(context: ExecutionContext): Promise<boolean> {
      const request = context.switchToHttp().getRequest();
      const user: JwtPayload = request.user;
      const resourceId = request.params.id;

      if (!resourceId || isNaN(+resourceId) || +resourceId <= 0 || resourceId==null || Number.isNaN(resourceId)) return true;
      console.log(resourceId, request.route.path);;

      const repository = this.dataSource.getRepository(entityClass);
      const resource = await repository.findOne({
        where: { id: +resourceId },
        relations: ['company'],
      });

      if (!resource) {
        throw new ForbiddenException('Resource not found');
      }

      if (resource.company?.code !== user.companyCode) {
        throw new ForbiddenException('You do not have access to this resource');
      }

      return true;
    }
  }

  return mixin(CompanyAccessGuardMixin);
};