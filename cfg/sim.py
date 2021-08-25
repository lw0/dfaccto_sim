Inc('dfaccto.py', abs='lib')


Pkg('dfaccto_sim',
    x_templates={File('interface.vhd.tpl') : File('pkg/dfaccto_sim.vhd')})

class SimPort:

  @classmethod
  def Sys(cls, name, type):
    return cls._create(name, type, None, None, PortI, 'x_is_sys')

  @classmethod
  def Output(cls, name, type):
    return cls._create(name, type, 'unsigned', 'output', PortI, 'x_is_unsigned')

  @classmethod
  def Input(cls, name, type):
    return cls._create(name, type, 'unsigned', 'input', PortO, 'x_is_unsigned')

  @classmethod
  def Push(cls, name, type):
    return cls._create(name, type, 'event', 'push', PortS, 'x_is_event')

  @classmethod
  def Pull(cls, name, type):
    return cls._create(name, type, 'event', 'pull', PortM, 'x_is_event')

  @classmethod
  def Source(cls, name, type):
    return cls._create(name, type, 'stream', 'source', PortS, 'x_is_axi_stream')

  @classmethod
  def Sink(cls, name, type):
    return cls._create(name, type, 'stream', 'sink', PortM, 'x_is_axi_stream')

  @classmethod
  def Master(cls, name, type):
    return cls._create(name, type, 'memory', 'master', PortS, 'x_is_axi')

  @classmethod
  def Slave(cls, name, type):
    return cls._create(name, type, 'memory', 'slave', PortM, 'x_is_axi')

  @classmethod
  def _create(cls, name, type, group, kind, port_func, type_check):
    return cls(name, type, group, kind, port_func, type_check)

  def __init__(self, name, type, group, kind, port_func, type_check):
    if not getattr(type, type_check, False):
      raise ValueError('{} interface expects type with {} flag, got "{}"'.format(kind, type_check, type))
    self.name = name
    self.type = type
    self.group = group
    self.kind = kind
    self.port_func = port_func


def _EntTestbench(ctx, *interfaces):
  ports = []
  for intf in interfaces:
    if not isinstance(intf, SimPort):
      raise ValueError('EntTestbench() expects SimPort interfaces, got "{}"'.format(intf))
    ports.append(intf.port_func(intf.name, intf.type,
        x_interface=intf.kind,
        x_vars=intf.group and ctx.Part('vars_{}.part.tpl'.format(intf.group)),
        x_update=intf.kind and ctx.Part('update_{}.part.tpl'.format(intf.kind)),
        x_state=intf.kind and ctx.Part('state_{}.part.tpl'.format(intf.kind))))

  return Ent('Testbench',
      *ports,
      x_clocknanos=1,
      x_interfacepkg=P('dfaccto_sim'),
      x_templates={ctx.File('testbench.vhd.tpl') : ctx.File('Testbench.vhd')})
EntTestbench = ModuleContext(_EntTestbench)

