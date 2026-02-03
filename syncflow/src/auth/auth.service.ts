import { Injectable, UnauthorizedException } from '@nestjs/common';
import { LoginDto } from './dto/login.dto';
import * as bcrypt from 'bcrypt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../user/entities/user.entity';
import { JwtService, JwtSignOptions } from '@nestjs/jwt';
import { Company } from '../company/entities/company.entity';
import { Role } from '../enum/role.enum';
import { CreateUserDto } from './dto/create-user.dto';
import { JwtPayload } from './jwt-payload.interface';
import { CreateEventService } from 'src/history/create-event.service';
import { OperationType } from 'src/enum/operation-type';
import { Operation } from 'src/history/entities/operation.entity';
import { UserService } from 'src/user/user.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { CreateOperationDto } from 'src/history/dto/create-operation.dto';
import { Target } from 'src/enum/target.enum';
import { SharedService } from 'src/services/shared.services';
import { ConfigService } from 'src/config/config.service';
import { UserSelectOptions } from 'src/user/dto/select-user.dto';

@Injectable()
export class AuthService {
  accessSecret: string;
  accessExpiresIn: string;
  refreshSecret: string;
  refreshExpiresIn: string;
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private jwtService: JwtService,
    @InjectRepository(Operation)
    private eventRepository: Repository<Operation>,
    private eventEmitter: EventEmitter2,
    private readonly configService: ConfigService,

  ) { 
    const jwtConfig = this.configService.getJwtConfig();
    this.accessSecret = jwtConfig.jwtSecret;
    this.accessExpiresIn = jwtConfig.jwtExpiration;
    this.refreshSecret = jwtConfig.jwtRefreshSecret;
    this.refreshExpiresIn = jwtConfig.jwtRefreshExpiration;
  }
  async createUser(createUserDto: CreateUserDto, manager: JwtPayload,): Promise<User> {
    const { username, password, role } = createUserDto;

    const company = await this.userRepository.manager
      .getRepository(Company)
      .findOne({ where: { code: manager.companyCode } });
    if (!company) {
      throw new UnauthorizedException('Invalid company code');
    }
    const existing = await this.userRepository.findOne({ where: { username, company: { id: company.id } } });
    if (existing) {
      throw new UnauthorizedException('Username already exists in this company');
    }
    const salt = await bcrypt.genSalt();
    const hashedPassword = await bcrypt.hash(password, salt);

    const user = this.userRepository.create({
      username,
      password: hashedPassword,
      salt,
      company,
      role: role ?? Role.USER,
    });

    const managerUser = await this.userRepository.findOne({ where: { id: manager.sub } });
    if (!managerUser) {
      throw new UnauthorizedException('Manager user not found');
    }
    const savedUser = await this.userRepository.save(user);
    const { company: _company, ...actdata } = savedUser;
    actdata.password = '';
    actdata.salt = '';
    const op: CreateOperationDto = {
      type: OperationType.CREATE,
      description: JSON.stringify(actdata),
      performedBy: managerUser,
      target: savedUser.id,
      targettype: Target.USER,
      date: new Date(),
      company: company,
    };
    const newEvent = this.eventRepository.create(op);
    await this.eventRepository.save(newEvent);
    this.eventEmitter.emit(`event.created.${user.company?.code}`, newEvent);
    const newlyCreatedUser = await this.userRepository.findOne({
      where: { id: savedUser.id },
      select: UserSelectOptions,
      relations: ['company'],
    });
    return savedUser;
  }

  async refresh(refreshToken: string): Promise<{ access_token: string, refresh_token: string }> {
  try {
    const lpayload = await this.jwtService.verifyAsync(refreshToken, 
      {secret : this.refreshSecret,}
    );
    const user = await this.userRepository.createQueryBuilder("user")
    .innerJoin("user.company", "company")
    .where("user.id = :id", { id: lpayload.sub })
    .andWhere("company.code = :companyCode", { companyCode: lpayload.companyCode })
    .getOne();


    if (!user) throw new UnauthorizedException('User no longer exists');
    const payload: JwtPayload = {
      username: lpayload.username,
      sub: lpayload.sub,
      role: lpayload.role,
      companyCode: lpayload.companyCode
    };

    const access_token = this.jwtService.sign(payload, {
      secret: this.accessSecret,
      expiresIn: this.accessExpiresIn,
    } as JwtSignOptions);

    const refresh_token = this.jwtService.sign(payload, {
      secret: this.refreshSecret,
      expiresIn: this.refreshExpiresIn,
    } as JwtSignOptions);
    
    return { access_token: access_token, refresh_token: refresh_token };
  } catch (err) {
    throw new UnauthorizedException('Invalid or expired refresh token');
  }
}
  async login(loginDto: LoginDto): Promise<{ access_token: string, refresh_token: string }> {
    const { username, password, companyCode } = loginDto;
    const company = await this.userRepository.manager
      .getRepository(Company)
      .findOne({ where: { code: companyCode }, relations: ['users'] });

    if (!company) {
      throw new UnauthorizedException('Invalid company code');
    }

    const user = await this.userRepository.findOne({
      where: { username, company: { id: company.id } },
      relations: ['company']
    });

    if (!user || !(await bcrypt.compare(password, user.password))) {
      throw new UnauthorizedException('Identifiants invalides');
    }

    const payload: JwtPayload = { username: user.username, sub: user.id, role: user.role, companyCode: company.code };

    const access_token = this.jwtService.sign(payload, {
      secret: this.accessSecret,
      expiresIn: this.accessExpiresIn,
    } as JwtSignOptions);

    const refresh_token = this.jwtService.sign(payload, {
      secret: this.refreshSecret,
      expiresIn: this.refreshExpiresIn,
    } as JwtSignOptions);

    return { access_token, refresh_token };
  }

  async deleteUser(userId: number, manager: JwtPayload): Promise<void> {
    const user = await this.userRepository.findOne({ where: { id: userId }, relations: ['company'] });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    if (user.company.code !== manager.companyCode) {
      throw new UnauthorizedException('You do not have permission to delete this user');
    }
    if (user.id === manager.sub) {
      throw new UnauthorizedException('You cannot delete yourself');
    }

    const managerEntity = await this.userRepository.findOne({ where: { id: manager.sub } });
    if (!managerEntity) {
      throw new UnauthorizedException('Manager user not found');
    }
    const userData = {
      id: user.id,
      username: user.username,
      role: user.role,
      company: user.company.code,
    }
    await this.userRepository.softDelete(user.id);

    const op: CreateOperationDto = {
      type: OperationType.DELETE,
      description: JSON.stringify(userData),
      performedBy: managerEntity,
      target: user.id,
      targettype: Target.USER,
      date: new Date(),
      company: user.company,
    };
    const newEvent = this.eventRepository.create(op);
    await this.eventRepository.save(newEvent);
    this.eventEmitter.emit(`event.created.${user.company.code}`, newEvent);
  }

  async logout(user: JwtPayload): Promise<{ message: string }> {
    return { message: 'Successfully logged out' };
  }
}
