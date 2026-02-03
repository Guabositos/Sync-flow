import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserService } from './user.service';
import { UserController } from './user.controller';
import { User } from './entities/user.entity';
import { UserEvents } from './user.events';
import { Company } from '../company/entities/company.entity';
import { Operation } from '../history/entities/operation.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Company, Operation]),
  ],
  providers: [UserService, UserEvents],
  controllers: [UserController],
  exports: [UserService],
})
export class UserModule {}
