import { Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Chat } from './entities/chat.entity';
import { Message } from './entities/message.entity';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { User } from 'src/user/entities/user.entity';
import { Company } from 'src/company/entities/company.entity';
import { ChatResponseDto } from './dto/chat-response.dto';
import { MessageResponseDto } from './dto/message-response.dto';
import { PaginationDto } from 'src/services/pagination.dto';

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Chat)
    private chatRepository: Repository<Chat>,
    @InjectRepository(Message)
    private messageRepository: Repository<Message>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Company)
    private companyRepository: Repository<Company>,
  ) {}

  async createChat(createChatDto: CreateChatDto, user: JwtPayload): Promise<ChatResponseDto> {
    const company = await this.companyRepository.findOne({
      where: { code: user.companyCode }
    });

    if (!company) {
      throw new UnauthorizedException('Invalid company');
    }

    const chat = this.chatRepository.create({
      name: createChatDto.name,
      company,
    });

    const savedChat = await this.chatRepository.save(chat);

    return {
      id: savedChat.id,
      name: savedChat.name,
      type: savedChat.type,
      createdAt: savedChat.createdAt,
    };
  }

  async getCompanyChats(user: JwtPayload, paginationDto?: PaginationDto): Promise<ChatResponseDto[]> {
    const take = paginationDto?.limit || 20;
    const skip = paginationDto?.offset || 0;
    const chats = await this.chatRepository.find({
      where: { company: { code: user.companyCode } },
      relations: ['messages', 'messages.sender'],
      order: { updatedAt: 'DESC' },
      take,
      skip,
      select: ['id', 'name', 'type', 'createdAt', 'updatedAt'],
    });

    return chats.map((chat) => {
      const messages = chat.messages ?? [];
      const sortedMessages = messages
        .slice()
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
      const messageCount = sortedMessages.length;
      const lastMessageEntity = sortedMessages[messageCount - 1];

      return {
        id: chat.id,
        name: chat.name,
        type: chat.type,
        createdAt: chat.createdAt,
        messageCount,
        lastMessage: lastMessageEntity
          ? {
              content: lastMessageEntity.content,
              senderUsername: lastMessageEntity.sender?.username ?? 'Unknown',
              createdAt: lastMessageEntity.createdAt,
            }
          : undefined,
      };
    });
  }

  async getChatMessages(chatId: number, user: JwtPayload, paginationDto?: PaginationDto): Promise<MessageResponseDto[]> {
    const limit = paginationDto?.limit || 50;
    const offset = paginationDto?.offset || 0;
    const chat = await this.chatRepository.findOne({
      where: { id: chatId, company: { code: user.companyCode } },
    });

    if (!chat) {
      throw new NotFoundException('Chat not found or access denied');
    }

    const messages = await this.messageRepository.find({
      where: { chat: { id: chatId } },
      relations: ['sender'],
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });

    return messages.reverse().map(message => ({
      id: message.id,
      content: message.content,
      createdAt: message.createdAt,
      sender: {
        id: message.sender.id,
        username: message.sender.username,
      },
    }));
  }

  async sendMessage(sendMessageDto: SendMessageDto, user: JwtPayload, chatId: number): Promise<MessageResponseDto> {
    // Verify user has access to this chat
    console.log('User:', user);
    console.log('SendMessageDto:', sendMessageDto);
    const chat = await this.chatRepository.findOne({
      where: { id: chatId, company: { code: user.companyCode } },
    });
    
    const sender = await this.userRepository.findOne({
      where: { id: user.sub },
    });

    if (!sender) {
      throw new UnauthorizedException('User not found');
    }
    if (!chat) {
      throw new NotFoundException('Chat not found or access denied');
    }

    const message = this.messageRepository.create({
      content: sendMessageDto.content,
      chat,
      sender,
    });

    const savedMessage = await this.messageRepository.save(message);

    // Update chat's updatedAt timestamp
    await this.chatRepository.update(chat.id, { updatedAt: new Date() });

    return {
      id: savedMessage.id,
      content: savedMessage.content,
      createdAt: savedMessage.createdAt,
      sender: {
        id: sender.id,
        username: sender.username,
      },
    };
  }

  async deleteChat(chatId: number, user: JwtPayload): Promise<void> {
    const chat = await this.chatRepository.findOne({
      where: { id: chatId, company: { code: user.companyCode } },
    });
    console.log('Chat to delete:', chat);
    if (!chat) {
      throw new NotFoundException('Chat not found or access denied');
    }

    await this.chatRepository.softDelete(chatId);
  }

  async checkUserAccessToChatRoom(user: JwtPayload, chatId: number): Promise<boolean> {
    const $user  = await this.userRepository.findOne({
      where: { id: user.sub },relations: ['company'], select: { id: true, company: { id: true } }
    });
    const chat = await this.chatRepository.findOne({
      where: { id: chatId }, relations: ['company'], select: { id: true, company: { id: true } }
    });
    if(!chat || ! $user) {
      return false;
    }
    return $user.company.id === chat.company.id;
  }
}