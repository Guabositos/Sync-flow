import { Controller, UseGuards, Sse, Get, Param, Body, Patch, Delete, Post } from '@nestjs/common';
import { UserService } from './user.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ConnectedUser } from '../auth/decorator/user.decorator';
import { JwtPayload } from '../auth/jwt-payload.interface';
import { Observable, of } from 'rxjs';
import { UserEvents } from './user.events';
import { User } from './entities/user.entity';
import { Roles } from 'src/auth/decorator/roles.decorator';
import { Role } from 'src/enum/role.enum';
import { UpdateUserDto } from './dto/update-user.dto';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Company } from 'src/company/entities/company.entity';
import { CompanyAccessGuard } from 'src/company-access/company-access.guard';
import { RolesGuard } from 'src/auth/role-guard';

@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles([Role.MANAGER])
export class UserController {
  constructor(
    private readonly userService: UserService,
    private readonly userEvents: UserEvents,
    private readonly eventEmitter: EventEmitter2
  ) {}

 @Get('deleted')
  async findDeleted(@ConnectedUser() user: JwtPayload): Promise<User[]> {
  return this.userService.findDeletedByCompany(user.companyCode);
}

  @Get('company')
  async getUsersByCompany(@ConnectedUser() user: JwtPayload): Promise<User[]> {
    return this.userService.getUsersByCompany(user.companyCode);
  }


  @Get('by-username/:username')
  async findByUsername(
    @Param('username') username: string,
    @ConnectedUser() user: JwtPayload
  ): Promise<User | null> {
    return this.userService.findOneByUsername(username, user.companyCode);
  }

  

  @Sse('events')
  events(@ConnectedUser() user: JwtPayload): Observable<any> {
    if (!user.sub) {
      return of({ type: 'error', data: 'No user ID found' });
    }
    const stream = this.userEvents.getUserStream(user.sub.toString());
    if (!stream) {
      return of({ type: 'error', data: 'Stream not available' });
    }
    return stream;
  }

  @Get('usernames')
  async getUserNames(@ConnectedUser() user: JwtPayload): Promise<{username: string, id: number}[]> {
    console.log("Controller: Fetching usernames for company code:", user.companyCode);
    const res = await this.userService.getUsernames(user.companyCode);
    console.log(res);
    return res;
  }

   @Get('current')
  async currentUser(@ConnectedUser() user : JwtPayload): Promise<User> {
    console.log(this.userService.findOne(user.sub));
    return this.userService.findOne(user.sub);
  }

  @UseGuards(CompanyAccessGuard(User))
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<User> {
    return this.userService.findOne(+id);
  }

 
  
  @UseGuards(CompanyAccessGuard(User))
  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() updateUserDto: UpdateUserDto,
    @ConnectedUser() user: JwtPayload
  ): Promise<User> {
    const updatedUser = await this.userService.update(+id, updateUserDto, user);
    this.eventEmitter.emit('user.updated', updatedUser);
    return updatedUser;
  }

  @UseGuards(CompanyAccessGuard(User))
  @Delete(':id')
  async remove(@Param('id') id: string, @ConnectedUser() user: JwtPayload) {
    const userToDelete = await this.userService.findOne(+id);
    await this.userService.remove(+id, user);
    this.eventEmitter.emit('user.deleted', userToDelete);
    return { success: true };
  }

 
  @Post(':id/recover')
  async recover(@Param('id') id: string, @ConnectedUser() user: JwtPayload): Promise<User> {
    const recoveredUser = await this.userService.recover(+id, user);
    this.eventEmitter.emit('user.recovered', recoveredUser);
    return recoveredUser;
  }
}
