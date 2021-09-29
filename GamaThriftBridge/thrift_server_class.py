#!/usr/bin/env python
 
import sys
 
# GamaThrift files
from GamaThrift import MmtService
from GamaThrift import PlannerService
from GamaThrift import *
from GamaThrift.ttypes import *
 
from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol
from thrift.server import TServer
 
import socket
from threading import Lock
import copy
 
class Handler(MmtService.Iface):
  def __init__(self):
    self.log = {}
    self.currentPlan = []

    self.executedPlan = []
    self.plan_dealt_with = True
    self.check_for_tg = False
    self.isPlanNew = False
    self.complete = [0 , False]
    self.mission_status = "nomission"
    self.lock = Lock()

    self.noplans = 0
    self.total_actions = 0
    self.first_equip = []
    self.previous_plan = []
    self.assigned_agents = []

    self.tasks_equips = []

    self.time_of_arrival = -1
 
  def ping(self):
    print "ping() or whatever"
    return "done"
 
  def setPlanNewValue(self, value):
    with self.lock:
      self.isPlanNew = value

  def sendPlan(self, plan):
    print "I got a new plan"
    #print plan.vehicles
    plan_copy = copy.deepcopy(plan)

    notransits = []
    for x in plan_copy.actions:
      if not x.relatedTask.description == "Transit":
        notransits.append(x)

    plan_copy.actions = notransits

    print "Nr of actions: %d" % len(plan_copy.actions)
    #print [x.relatedTask.description for x in plan_copy.actions]
    #print [[x.area.area[0].latitude, x.area.area[0].longitude]for x in plan_copy.actions]
    #plan_copy.vehicles[0].onboardPlanner = True
    #print plan_copy.vehicles[0].onboardPlanner
    with self.lock:
      self.complete = [self.complete[0]+1, False]
      self.previous_plan = copy.deepcopy(self.currentPlan)
      self.mission_status = "running"
      self.assigned_agents = []

      self.tasks_equips.append([])
      self.tasks_equips[-1] = [[x.actionId, [str(i) for i in x.relatedTask.requiredTypes]] for x in plan_copy.actions]
      #print self.tasks_equips

      for x in plan_copy.actions:
        if not x.assignedVehicleId in self.assigned_agents:
          self.assigned_agents.append(x.assignedVehicleId)
      #print self.assigned_agents
      self.currentPlan = plan_copy
      self.isPlanNew = True
      self.noplans += 1
    return 0