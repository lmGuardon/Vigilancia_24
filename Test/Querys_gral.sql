-- 1. Despues de crear un usuario nuevo con dbo.sp_CreateUser, ejecutamos esta query.
SELECT [id]
      ,[name]
      ,[email]
      ,[password_hash]
      ,[profile_id]
      ,[created_at]
  FROM [TanoSQL_Vigilancia24].[dbo].[users]