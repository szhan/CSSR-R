package com.typeclassified.cssr.test

import com.typeclassified.cssr.CausalState
import com.typeclassified.cssr.EquivalenceClass
import com.typesafe.scalalogging.Logger
import org.slf4j.LoggerFactory

import scala.collection.mutable.ListBuffer

object Test {
  val logger = Logger(LoggerFactory.getLogger(Test.getClass))

  def test(S: ListBuffer[EquivalenceClass],
           p: Double,
           aXt: CausalState,
           s: EquivalenceClass,
           sig: Double
          ) = {
    if (nullHypothesis(s, aXt) > sig) {
      if (!s.histories.contains(aXt)) {
        aXt.changeEquivalenceClass(s)
        s.addHistory(aXt)
      }
    } else {
      val sStar: Option[EquivalenceClass] = restrictedHypothesesTesting(S.toList, s, aXt, sig)
      if (sStar.nonEmpty) {
        move(aXt, s, sStar.get)
      } else {
        logger.info(s"Generating a new equivalence class with: ${aXt.value}")
        var sNew = EquivalenceClass()
        S += sNew
        move(aXt, s, sNew)
      }
    }
  }

  def nullHypothesis(s: EquivalenceClass, aXt: CausalState): Double = {
    KolmogorovSmirnov
      .test(
        s.distribution,
        s.totalCounts,
        aXt.distribution,
        aXt.totalCounts)
  }

  def restrictedHypothesesTesting(S: List[EquivalenceClass],
                                  s: EquivalenceClass,
                                  ax: CausalState,
                                  sig: Double
                                 ): Option[EquivalenceClass] = {
    val SStar = S.filter(_ != s)
    for (sStar <- SStar) {
      if (nullHypothesis(sStar, ax) > sig) {
        return Option.apply(sStar)
      }
    }
    Option.empty
  }

  def move(x: CausalState, from: EquivalenceClass, to: EquivalenceClass): Unit = {
    from.rmHistory(x)
    to.addHistory(x)
  }
}
