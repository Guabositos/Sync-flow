    import { Target } from "src/enum/target.enum";

    export const Query = {
        hello: (_parent: any, _args: any, _context) => {
            return 'Hello World!';
        },
        users(_parent: any, _args: any, context) {
            return context.userService.getAllUsers();
        },
        async NoteLines(_parent: any, _args: {noteId: number, start:number, limit: number}, context) {
            const note = await context.noteService.getNoteById(_args.noteId);
            if (!note) {
                throw new Error(`Note with ID ${_args.noteId} not found`);
            }
            if (note.company.code !== context.user.companyCode) {
                throw new Error(`You do not have access to this note`);
            }
            const notelines = await context.noteLineService.getNoteLinesByNoteId(_args.noteId, _args.limit, _args.start);
            return notelines;
        },
        
    }