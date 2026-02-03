import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/role-guard';
import { Roles } from 'src/auth/decorator/roles.decorator';
import { ConnectedUser } from 'src/auth/decorator/user.decorator';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { Role } from 'src/enum/role.enum';
import { PaginationDto } from 'src/services/pagination.dto';
import { CompanyAccessGuard } from 'src/company-access/company-access.guard';
import { Chat } from './entities/chat.entity';
import { ChatResponseDto } from './dto/chat-response.dto';

/*
  !!!
  when adding new routes (specifically those like post and put) always put the id of the resource in the param and add the company-access guard to ensure only users from the same company can access the resource
  see   @Get(':id/messages') for example
  !!!
*/

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles([Role.MANAGER])
  async createChat(
    @Body() createChatDto: CreateChatDto,
    @ConnectedUser() user: JwtPayload,
  ) {
    return this.chatService.createChat(createChatDto, user);
  }

  @Get()
  async getChats(
    @ConnectedUser() user: JwtPayload,
    @Query() paginationDto?: PaginationDto,
  ): Promise<ChatResponseDto[]> {
    return this.chatService.getCompanyChats(user, paginationDto);
  }

  @UseGuards(CompanyAccessGuard(Chat))
  @Get(':id/messages')
  async getChatMessages(
    @Param('id', ParseIntPipe) chatId: number,
    @ConnectedUser() user: JwtPayload,
    @Query() paginationDto?: PaginationDto,
  ) {
    return this.chatService.getChatMessages(chatId, user, paginationDto);
  }

  @UseGuards(CompanyAccessGuard(Chat))
  @Post(':id/message')
  async sendMessage(
    @Body() sendMessageDto: SendMessageDto,
    @ConnectedUser() user: JwtPayload,
    @Param('id', ParseIntPipe) chatId: number,
  ) {
    return this.chatService.sendMessage(sendMessageDto, user, chatId);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles([Role.MANAGER])
  async deleteChat(
    @Param('id', ParseIntPipe) chatId: number,
    @ConnectedUser() user: JwtPayload,
  ) {
    return this.chatService.deleteChat(chatId, user);
  }
}
