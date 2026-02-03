import { Expose } from "class-transformer";

export const NoteLine = {
  async lastEditedBy(parent: any, _args: any, context) {
    if (!parent.lastEditedById) return null; // ✅ handles nulls

    // Fetch only when needed
    return context.userService.findOne(parent.lastEditedById);
  }}
  export const Operation = {
  async performedBy(parent: any, _args: any, context) {
    if (!parent.performedById) return null;

    // Fetch only when needed
    return context.userService.findOne(parent.performedById);
  }
};
export const Event =  {
  async createdBy(parent: any, args: { companyCode: string, limit?: number, offset?: number }, context) {
    console.log(parent, 'parent')
    if (!parent.createdById)
    {
      return null
    }
    const res =  await  context.userService.findOne(parent.createdById);
    console.log("res", res);
    return res;
}
};
