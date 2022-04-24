create database HopeApp;
use HopeApp;
CREATE TABLE if not exists usuarios(
id bigint,
nombre varchar(50) not null,
apellidos varchar(50) not null,
edad int not null,
email longtext not null,
password longtext not null,
ruta_foto text not null,
fecha_alta datetime not null,
 primary key(id)
);
CREATE TABLE if not exists sintomas(
id bigint,
descripcion text not null,
 primary key(id)
);
CREATE TABLE if not exists intensidad_sintomas(
id bigint,
descripcion varchar(30) not null,
fecha_alta datetime not null,
primary key(id)
);
CREATE TABLE if not exists log_principal(
id bigint,
descripcion text not null,
fecha_registro datetime,
primary key(id)
);
create table estatus_conexion(
id int,
nombre_estatus varchar(50),
fecha_insercion datetime,
primary key(id)
);
create table tipos_cancer(
id int not null,
nombre_tipo varchar(25) not null,
fecha_insercion datetime,
primary key(id));
create table etapas_cancer(
id int not null,
nombre_etapa varchar(25) not null,
fecha_insercion datetime not null,
primary key(id)
);
/***************************************Tablas intermedias****************************************/
create table if not exists doctores(
id bigint auto_increment,
id_usuario bigint not null,
cedula varchar(100) not null,
id_estatus int,
ruta_img_historial text not null,
ruta_img_cert text not null,
primary key(id));
create table if not exists pacientes(
id bigint auto_increment,
id_usuario bigint not null,
id_etapa int,
id_tipo_cancer int,
ruta_expediente varchar(600),
primary key(id));
create table if not exists sintomas_pacientes(
id bigint auto_increment,
id_paciente bigint not null,
id_sintoma bigint not null,
id_intensidad bigint not null,
fecha_sintoma date,
hora_sintoma time not null,
detalles_adicionales text not null,
primary key(id)
);
create table if not exists usuarios_log(
id bigint auto_increment,
id_log bigint not null,
id_usuario bigint null,
primary key(id)
);
create table if not exists paciente_doctores_tutela(
id bigint not null auto_increment,
id_doctor bigint not null,
id_paciente bigint not null,
fecha_alta_tutela datetime not null,
fecha_baja_tutela datetime,
primary key(id)
);
/***************************Llaves primarias**********************/
alter table sintomas_pacientes
add foreign key (id_paciente) references pacientes(id),
add foreign key (id_sintoma) references sintomas(id),
add foreign key (id_intensidad) references intensidad_sintomas(id);
alter table usuarios_log
add foreign key (id_log) references log_principal(id),
add foreign key(id_usuario) references usuarios(id);
alter table paciente_doctores_tutela 
add foreign key (id_doctor) references doctores(id),
add foreign key (id_paciente) references pacientes(id);
alter table doctores
add foreign key (id_usuario) references usuarios(id);
alter table doctores 
add foreign key(id_estatus) references estatus_conexion(id);
alter table pacientes
add foreign key (id_etapa) references etapas_cancer(id);
alter table pacientes
add foreign key (id_tipo_cancer) references tipos_cancer(id);
alter table pacientes
add foreign key (id_usuario) references usuarios(id);
/********************SP de inserción**********************/
-- Funcion de corrección de hora
delimiter //
CREATE FUNCTION fn_Hora_Actual()
returns datetime
begin
return (select date_sub(NOW(), INTERVAL 6 HOUR));
end;
//
-- Funcion para validar si un doctor está activo
delimiter //
create function fn_Validar_Sesion_Activo(id_doctor int)
returns bit
return (select if(Status='Activo', 1,0) 'Status' from vw_doctores where id = id_doctor);//
-- Obtener el id del estatus
delimiter //
create function fn_Obtener_id_status_Conexion(status_ varchar(50))
returns int
return (select id from estatus_conexion where nombre_estatus = status_);//
-- Insercion de LOG
delimiter //
create procedure sp_InsertarLog(descripcion text, id_usuario bigint)
begin
	set @maxIdLog =  1;
	if (select max(id) from log_principal) is not null then
		set @maxIdLog = (select max(id) from log_principal) + 1;
	end if;
	INSERT INTO `log_principal` (`id`,`descripcion`,`fecha_registro`) VALUES(@maxIdLog,descripcion,fn_Hora_Actual());
    INSERT INTO `usuarios_log`(`id_log`,`id_usuario`) VALUES(@maxIdLog,id_usuario);
end;//
-- Insercion de usuario
delimiter //
create procedure sp_Insertar_Medico(nombre_ varchar(50), apellidos_ varchar(50), edad_ int, email_ longtext, pass_ longtext, cedula_ varchar(100), 
	especialidad_ varchar(30), estudios_ varchar(100), rutaHistorial_ text, rutaCertificado text ,rutaImgPerfil text ,idEjecutante bigint)
begin
	set @idUsuario = 1,
    @existeUsuario = (select if(count(*) >0,0,1) from usuarios where (nombre = nombre_ and apellidos = apellidos_ and edad = edad_ and email = email_));
    
    if @existeUsuario = 1 then
		if(select max(id) from usuarios) is not null then
			set @idUsuario = (select max(id) from usuarios)+1;
		end if;
        INSERT INTO `usuarios`
		(`id`,
		`nombre`,
		`apellidos`,
		`edad`,
		`email`,
		`password`,
        `ruta_foto`,
		`fecha_alta`)
		VALUES(
		@idUsuario,
		nombre_,
		apellidos_,
		edad_,
		email_,
		pass_,
        rutaImgPerfil,
		fn_Hora_Actual());
        INSERT INTO `doctores`
		(
		`id_usuario`,
		`cedula`,
		`id_estatus`,
		`ruta_img_historial`,
		`ruta_img_cert`)
		VALUES
		(@idUsuario,
		cedula_,
		2,
		rutaHistorial_,
		rutaCertificado);
        set @descripcion = concat('Se insertó un nuevo médico con cedula profesional: ', cedula_);
        call sp_InsertarLog(@descripcion,idEjecutante);
		select 1, concat('El Doctor ',nombre_,' se insertó correctamente');
	else
		select -1, concat('El Doctor ',nombre_,' ya está registrado.');
    end if;
end//
-- Insertar paciente
delimiter //
create procedure sp_Insertar_Paciente(nombre_ varchar(50), apellidos_ varchar(50), edad_ int, email_ longtext, pass_ longtext, tipo_cancer_ varchar(150), etapa_ varchar(60), ruta_ varchar(600),idEjecutante bigint)
begin
	set @idUsuario = 1,
    @existeUsuario = (select if(count(*) >0,0,1) from usuarios where (nombre = nombre_ and apellidos = apellidos_ and edad = edad_ and email = email_)),
    @idTipoCancer = (select id from tipos_cancer where nombre_tipo = tipo_cancer_),
    @idEtapa = (select id from etapas_cancer where nombre_etapa = etapa_);
    -- Verificacion e insercion de tipos de cancer
    if (@existeUsuario = 1) then
		if(select max(id) from usuarios) is not null then
			set @idUsuario = (select max(id) from usuarios)+1;
		end if;
        INSERT INTO `usuarios`
		(`id`,
		`nombre`,
		`apellidos`,
		`edad`,
		`email`,
		`password`,
		`fecha_alta`)
		VALUES(
		@idUsuario,
		nombre_,
		apellidos_,
		edad_,
		email_,
		pass_,
		fn_Hora_Actual());
        
        INSERT INTO `pacientes`
		(`id_usuario`,
		`id_etapa`,
		`id_tipo_cancer`,
		`ruta_expediente`)
 values(@idUsuario, @idEtapa, @idTipoCancer, ruta_);
        set @descripcion = concat('Se insertó un nuevo paciente con el nombre: ', nombre_);
        call sp_InsertarLog(@descripcion,idEjecutante);
		select 1, concat('El paciente ',nombre_,' se insertó correctamente');
	else
		select -1, concat('El Paciente ',nombre_,' ya está registrado.');
    end if;
end//
-- Insertar intensidad sintoma
delimiter //
create procedure sp_insertar_intensidad_sintomas(descripcion_intensidad varchar(30), id_usuario bigint)
begin
set @maxIdIntensidad = 1;
if  (select max(id) from intensidad_sintomas) is not null then
	set @maxIdIntensidad = (select max(id) from intensidad_sintomas) + 1;
end if;
insert into `intensidad_sintomas`(id,descripcion, fecha_alta) values(@maxIdIntensidad,descripcion_intensidad, fn_Hora_Actual());
set @descripcion = concat('Se insertó una nueva intensidad de sintoma llamada ',descripcion_intensidad);
call sp_InsertarLog(@descripcion, id_usuario);
end;//
-- Insertar sintomas
drop  procedure sp_insertar_sintoma_usuario;
delimiter //
create procedure sp_insertar_sintoma_usuario(descripcion_  text, fecha_ date,hora_ time, id_paciente_ bigint, descripcion_intensidad varchar(30), detalles_adicionales_ text)
begin
set @existeSintoma = (select if(count(*) >0, 1,0) from sintomas where descripcion = descripcion_);
	set @existeIntensidad = (select if(count(*) >0, 1,0) from intensidad_sintomas where descripcion = descripcion_intensidad);
    set @maxIdSintoma = 0;
    set @idIntensidad = 0;

	if( @existeSintoma = 0) then
		-- Definicion de Id para nuevo usuario
		set @maxIdSintoma  = 1;
		if (select max(id) from sintomas) is not null then
			set @maxIdSintoma = (select max(id) from sintomas) + 1;
        end if;
        INSERT INTO sintomas (`id`, `descripcion`) VALUES(@maxIdSintoma,descripcion_);
    end if;
    if(@existeIntensidad = 0) then
		if( select max(id) from intensidad_sintomas) is not null then
			set @idIntensidad = ( select max(id) from intensidad_sintomas) + 1;
            INSERT INTO intensidad_sintomas(`id`,`descripcion`,`fecha_alta`)VALUES (@idIntensidad,descripcion_intensidad,fn_Hora_Actual());
        end if;
		-- Obtencion del id de la intensidad
		set @idIntensidad = (select id from intensidad_sintomas where descripcion = descripcion_intensidad);
    end if;
	set @maxIdSintoma = (select id from sintomas where descripcion = descripcion_);
    set @idIntensidad = (select id from intensidad_sintomas where descripcion = descripcion_intensidad);
    INSERT INTO `sintomas_pacientes`
	(`id_paciente`,
	`id_sintoma`,
	`id_intensidad`,
    `fecha_sintoma`,
	`hora_sintoma`,
	`detalles_adicionales`)
	VALUES
	(id_paciente_,
	@maxIdSintoma,
	@idIntensidad,
    fecha_,
	hora_,
	detalles_adicionales_);
    SET @nombre_usuario = (select concat(us.nombre, ' ',us.apellidos) from usuarios us inner join pacientes p on us.id =p.id_usuario where p.id = id_paciente_);
    SET @descripcion = concat('Se insertó el sintoma "', descripcion_,'" con la intensidad: "',descripcion_intensidad,'" para el paciente con el Nombre: "',@nombre_usuario,'"');
    SET @id_usuario_ejecutante = (select fn_Buscar_Id_Usuario_Por_Nombre(@nombre_usuario));
    CALL sp_InsertarLog(@descripcion ,@id_usuario_ejecutante);
    select 1 'status', 'El sintoma fue registrado correctamente.';
end;//
delimiter //
create procedure sp_Insertar_Tutela(nombre_doctor varchar(100), nombre_paciente varchar(100), fecha_hora datetime, id_ejecutante bigint)
begin
set @idDoctor = fn_Obtener_Id_Doctor_Por_Nombre(nombre_doctor),
	@idPaciente =fn_Obtener_Id_Paciente_Por_Nombre(nombre_paciente),
    @existeBajoSupervision = (select if(count(*)>0,1,0) from paciente_doctores_tutela where id_paciente = @idPaciente and fecha_baja_tutela is null);
    if @existeBajoSupervision = 0 then
		start transaction;
			INSERT INTO `paciente_doctores_tutela`(`id_doctor`,`id_paciente`,`fecha_alta_tutela`,`fecha_baja_tutela`)VALUES(@idDoctor,@idPaciente,fecha_hora, null);
			set @descripcion = concat('El paciente ',nombre_paciente, ' ha quedado bajo supervisión del doctor ',nombre_doctor);
			CALL `sp_InsertarLog`(@descripcion ,id_ejecutante);
            if @@error_count <= 0 then
				select 1,concat('Se registró al paciente ',nombre_paciente,' bajo supervisión del ',nombre_doctor);
				commit;
			else 
				set @descripcion = concat('Ha ocurrido un error al asignar al paciente ',nombre_paciente, ' con el doctor ',nombre_doctor);
				CALL sp_InsertarLog(@descripcion ,id_ejecutante);
				rollback;
            end if;
        
	else
		set @nombre_medico_tutela =(select concat(dc.nombre,' ',dc.apellidos) from paciente_doctores_tutela pmt
        inner join vw_Doctores dc  on pmt.id_medico = dc.id
        where id_paciente = @idPaciente  and fecha_baja_tutela is null);
		select -1,concat('Este paciente ya está bajo la tutela del doctor ',@nombre_medico_tutela);
    end if;
end;//
delimiter //
create procedure sp_InsertarEstatus(nombre_estat varchar(50), id_executante bigint)
begin
set @idMax = 1;
	if (select max(id) from estatus_conexion) is not null then
		set @idMax = (select max(id) from estatus_conexion) + 1;
	end if;
    start transaction;
    insert into estatus_conexion(id, nombre_estatus, fecha_insercion) values(@idMax, nombre_estat, fn_Hora_Actual());
    set @descripcion = concat('Se insertó un nuevo estatus llamado: "',nombre_estat,'"');
    CALL sp_InsertarLog(@descripcion, id_executante);
    commit;

end;//
delimiter //
create procedure sp_Modificar_Status_Doctor(id_doctor_ bigint, nombre_estat varchar(50), id_user_exec bigint)
begin
	start transaction;
	set @idEstatus = (select id from estatus_conexion where nombre_estatus = nombre_estat);
	update doctores set id_estatus = @idEstatus where id = id_doctor_;
    set @nombre_doctor = (select concat(nombre,' ',apellidos) from usuarios us inner join doctores dc on us.id = dc.id_usuario where dc.id = id_doctor_);
    set @descripcion = concat('Se cambio el estatus del doctor ',@nombre_doctor,' al status: "',nombre_estat,'"');
    CALL sp_InsertarLog(@descripcion,id_user_exec);
    
    commit;
end;//
delimiter //
create procedure sp_Modificar_Status_Doctor_Api(id_doctor_ bigint, nombre_estat varchar(50), id_user_exec bigint)
begin
	start transaction;
	set @idEstatus = (select id from estatus_conexion where nombre_estatus = nombre_estat);
	update doctores set id_estatus = @idEstatus where id = id_doctor_;
    set @nombre_doctor = (select concat(nombre,' ',apellidos) from usuarios us inner join doctores dc on us.id = dc.id_usuario where dc.id = id_doctor_);
    set @descripcion = concat('Se cambio el estatus del doctor ',@nombre_doctor,' al status: "',nombre_estat,'"');
    CALL sp_InsertarLog(@descripcion,id_user_exec);
    select 1 'estatus', @descripcion 'Msg';
    commit;
end;//
delimiter //
create procedure sp_Insertar_Etapa_Cancer(nombre_etapa_ varchar(25), id_ejecutante bigint)
begin
set @idNuevaEtapa = 1;
	if(select max(id) from etapas_cancer) is not null then
		set @idNuevaEtapa = (select max(id) from etapas_cancer) + 1;
    end if;
	start transaction;
	INSERT INTO etapas_cancer
	(`id`,
	`nombre_etapa`,
	`fecha_insercion`)
	VALUES
	(@idNuevaEtapa,
	nombre_etapa_,
	fn_Hora_Actual());
	set @descripcion = concat('Se insertó una nueva etapa el cancer llamada:  "',nombre_etapa_,'"');
	CALL sp_InsertarLog(@descripcion,id_ejecutante);
	commit;
end;//
delimiter //
create procedure sp_Insertar_Tipos_Cancer(nombre_tipo_ varchar(25), id_ejecutante bigint)
begin
	set @id_tipo = 1;
	if(select max(id) from tipos_cancer) is not null then
		set @id_tipo = (select max(id) from tipos_cancer) + 1;
	end if;
    start transaction;
		INSERT INTO tipos_cancer
		(`id`,
		`nombre_tipo`,
		`fecha_insercion`)
		VALUES
		(@id_tipo,
		nombre_tipo_,
		fn_Hora_Actual());
        set @descripcion = concat('Se insertó un nuevo tipo de cancer llamado: "',nombre_tipo_,'"');
        CALL `sp_InsertarLog`(@descripcion, id_ejecutante);
    commit;
end;//
/***********************SP's para ver datos**********************/
-- Sp para el login de los doctores
delimiter //
CREATE PROCEDURE sp_Login_Doctores(correo_cedula varchar(100),pass longtext)
begin

	set @numFilas = (select if(us.id is not null , 1 ,0) 'Resultado' from usuarios us
	inner join doctores dr on dr.id_usuario = us.id
	where (dr.cedula = correo_cedula or us.email = correo_cedula) and us.password = pass);
	set @nombre_medico = (select fn_Get_Nombre_Doctor(correo_cedula));

if @numFilas = 1 then
    set @idDoctor = (select fn_Obtener_Id_Doctor_Por_Nombre(@nombre_medico));
    set @idUsuario = (select fn_Get_Id_Usuario_IdDoctor(@idDoctor));
	CALL sp_Modificar_Status_Doctor(@idDoctor, 'Activo', @idUsuario);
    set @descripcion = concat('Se inició sesión para el medico "', @nombre_medico,'"');
    
	CALL sp_InsertarLog(@descripcion, @idUsuario);
    select 1 'Rsp', concat('Bienvenido Doctor ', @nombre_medico) 'Msg';
else
	set @descripcion = concat('Se Intento iniciar sesión para el medico "', @nombre_medico,'". El usuario o la contraseña no son correctas.');
	CALL sp_InsertarLog(@descripcion, @idUsuario);
	select -1 'Rsp', concat('El usuario no existe o las credenciales no son correctas') 'Msg';
end if;
end;//
-- Sp para logout de doctores
delimiter //
create procedure sp_Log_Out_Doctores(email_cedula varchar(100))
begin
	set @id_Doctor =(select dr.id 'Resultado' from usuarios us inner join doctores dr on dr.id_usuario = us.id
	where dr.cedula = email_cedula or us.email = email_cedula);
    
    set @sesion_Esta_Activa = fn_Validar_Sesion_Activo(@id_Doctor);
    set @id_estatus_activo = (select fn_Obtener_id_status_Conexion('Inactivo'));
    set @nombre_doctor = fn_Get_Nombre_Doctor(email_cedula);
    set @id_usuario = fn_Get_Id_Usuario_IdDoctor(@id_Doctor);
    
    if @sesion_Esta_Activa = 1 then
		update doctores set id_estatus = @id_estatus_activo where id = @id_Doctor;
        set @descripcion = concat('Se cerró la sesión para el usuario "',@nombre_doctor,'"');
        CALL sp_InsertarLog(@descripcion, @id_usuario);
        select 1 'Rsp', concat('Se cerró la sesión para el usuario "',@nombre_doctor,'"') 'Msg';
	else
		set @descripcion = concat('La sesión del médico "',@nombre_doctor,'" ya estaba cerrada.');
        select -1 'Rsp', concat('La sesión del médico "',@nombre_doctor,'" ya estaba cerrada.') 'Msg';
        CALL sp_InsertarLog(@descripcion, @id_usuario);
    end if;
end;//
delimiter //
create procedure sp_Traer_Info_PosLogin_medico(email_cedula varchar(100))
begin
select dc.id 'Id Doctor',concat(us.nombre,' ',us.apellidos) 'Nombre completo', us.edad 'Edad', dc.cedula ,ec.nombre_estatus 'Estatus', us.email 'Email',us.ruta_foto 'Ruta Foto', 
cast(us.fecha_alta as date) 'Fecha alta' from doctores dc
inner join usuarios us on us.id = dc.id_usuario
inner join estatus_conexion ec on ec.id = dc.id_estatus where us.email = email_cedula or dc.cedula = email_cedula;
end;//
delimiter //
create procedure sp_Ver_Sintomas_Pacientes_Por_Fecha(id_paciente_ bigint, nombre_paciente_ varchar(100), fecha_inicio date, fecha_fin date)
begin
select sp.id 'id_sintoma', s.descripcion 'Sintoma', ins.descripcion 'Intensidad', sp.fecha_sintoma 'Fecha', sp.hora_sintoma 'Hora', sp.detalles_adicionales 'Detalles' from sintomas_pacientes sp
inner join sintomas s on sp.id_sintoma = s.id
inner join intensidad_sintomas ins on sp.id_intensidad = ins.id
inner join vw_pacientes vp on vp.id = sp.id_paciente
where (concat(vp.nombre,' ',vp.apellidos) = nombre_paciente_ or vp.id = id_paciente_)
and (fecha_sintoma between fecha_inicio and fecha_fin);
end;//

/****************Vistas de modificación de datos***********************/
delimiter //
create view vw_Doctores
as
(select dc.id, us.nombre, us.apellidos, dc.cedula, ec.nombre_estatus 'Status' from  doctores dc 
inner join usuarios us on us.id = dc.id_usuario
inner join estatus_conexion ec on ec.id = dc.id_estatus);//
delimiter //
create view vw_Pacientes
as
(select pa.id, us.nombre, us.apellidos, tc.nombre_tipo, ec.nombre_etapa from  pacientes pa 
inner join usuarios us on us.id = pa.id_usuario
inner join tipos_cancer tc on tc.id = pa.id_tipo_cancer
inner join etapas_cancer ec on pa.id_etapa = ec.id);
//
delimiter //
create view vw_Acciones_Usuario as
select concat(us.nombre,' ',us.apellidos) 'Nombre usuario', lp.descripcion 'Descripcion', cast(fecha_registro as date) 'Fecha', cast(fecha_registro as time) 'Hora' from log_principal lp 
inner join usuarios_log ul on ul.id_log = lp.id
inner join usuarios us on us.id = ul.id_usuario
;
//
delimiter //
create view vw_vista_pacientes_movil_sin_tutela
as
(select us.nombre 'nombre',us.apellidos 'Apellidos', us.edad, ec.nombre_etapa 'etapa', tc.nombre_tipo 'tipo', us.ruta_foto 'foto_perfil' from usuarios us
inner join pacientes pc on us.id = pc.id_usuario
inner join etapas_cancer ec on ec.id = pc.id_etapa
inner join tipos_cancer tc on tc.id = pc.id_tipo_cancer
left join paciente_doctores_tutela pdt on pdt.id_paciente = pc.id
where pdt.id_paciente is null);//
drop procedure sp_Ver_Sintomas_Pacientes;
delimiter //
create procedure sp_Ver_Sintomas_Pacientes(id_paciente_ bigint, nombre_paciente_ varchar(100))
begin
select sp.id 'id_sintoma', s.descripcion 'Sintoma', ins.descripcion 'Intensidad', sp.fecha_sintoma 'Fecha', sp.hora_sintoma 'Hora', sp.detalles_adicionales 'Detalles' from sintomas_pacientes sp
inner join sintomas s on sp.id_sintoma = s.id
inner join intensidad_sintomas ins on sp.id_intensidad = ins.id
inner join vw_pacientes vp on vp.id = sp.id_paciente
where concat(vp.nombre,' ',vp.apellidos) = nombre_paciente_ or vp.id = id_paciente_;
end;//
/*****************************Funciones******************************/
delimiter //
create function fn_Obtener_Id_Doctor_Por_Nombre(nombre_completo varchar(100))
returns bigint
begin
set @resultado = (select id from vw_Doctores where concat(nombre,' ',apellidos) = nombre_completo);
return @resultado;
end//
delimiter //
create function fn_Obtener_Id_Paciente_Por_Nombre(nombre_completo varchar(100))
returns bigint
begin
set @resultado = (select id from vw_Pacientes where concat(nombre,' ',apellidos) = nombre_completo);
return @resultado;
end//
delimiter //
create function fn_Get_Nombre_Doctor(cedula_o_correo  varchar(150))
returns varchar(100)
begin
return (select concat(us.nombre, ' ',us.apellidos) from usuarios us inner join doctores dr on dr.id_usuario = us.id
							where (dr.cedula = cedula_o_correo or us.email = cedula_o_correo) );
end;//
delimiter //
create function fn_Buscar_Id_Usuario_Por_Nombre(nombre_completo_ varchar(100))
returns bigint
begin
return (select id from usuarios where concat(nombre,' ',apellidos) = nombre_completo_);
end;//
delimiter //
create function fn_Get_Id_Usuario_IdDoctor(IdMedico bigint)
returns bigint
begin
set @idUsuario = (select id_usuario from doctores where id = IdMedico);
return @idUsuario;
end;//
delimiter //
create function fn_Get_Id_Usuario_IdPaciente(IdPaciente bigint)
returns bigint
begin
set @idUsuario = (select id_usuario from pacientes where id = IdPaciente);
return @idUsuario;
end;//
delimiter //
create function fn_verificar_si_existe_usuario(nombre_ varchar(50), apellidos_ varchar(50), 
email_ longtext)
returns bit
return (select if(count(*)>0, 1, 0) 'resultado' from usuarios where nombre =nombre_ and apellidos = apellidos_ and email = email_);
//
/**********************************Insertar valores iniciales***********************/
-- Insertar administrador maestro
INSERT INTO `usuarios`(`id`,`nombre`,`apellidos`,`edad`,`email`,`password`,`ruta_foto`,`fecha_alta`) VALUES(1,'Administrador','Maestro',21,'admin@hopeapp.com',(select sha1('12345')),'/Archivos/Admin/FP_AdminMaster.png',fn_Hora_Actual());
-- Insertar intensidad de sintomas
call sp_insertar_intensidad_sintomas('Insportable',1);
call sp_insertar_intensidad_sintomas('Alta',1);
call sp_insertar_intensidad_sintomas('Media',1);
call sp_insertar_intensidad_sintomas('Baja',1);
call sp_insertar_intensidad_sintomas('Soportable',1);
-- Insertar estatus de conexión
call sp_InsertarEstatus('Activo',1);
call sp_InsertarEstatus('Inactivo',1);
call sp_InsertarEstatus('En consulta',1);
call sp_InsertarEstatus('Fuera de consultorio',1);
-- Insertar etapas de cancer
CALL sp_Insertar_Etapa_Cancer('Polipo', 1);
CALL sp_Insertar_Etapa_Cancer('Etapa 1', 1);
CALL sp_Insertar_Etapa_Cancer('Etapa 2', 1);
CALL sp_Insertar_Etapa_Cancer('Etapa 3', 1);
CALL sp_Insertar_Etapa_Cancer('Etapa 4', 1);
CALL sp_Insertar_Etapa_Cancer('Terminal', 1);
-- Insertar tipos de cancer
CALL sp_Insertar_Tipos_Cancer('Cancer de cabeza', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de cuello', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de Colon', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de cuello Uterino', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de ovario', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de útero', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de vagina', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de vulva', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de higado', 1);
CALL sp_Insertar_Tipos_Cancer('Linfoma', 1);
CALL sp_Insertar_Tipos_Cancer('Mesotelioma', 1);
CALL sp_Insertar_Tipos_Cancer('Mieloma', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de piel', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de prostata', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de pulmón', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de riñón', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de tiroide', 1);
CALL sp_Insertar_Tipos_Cancer('Cancer de vejiga', 1);
-- Select Tablas
select * from intensidad_sintomas;
select * from estatus_conexion;
select * from etapas_cancer;
select * from tipos_cancer;